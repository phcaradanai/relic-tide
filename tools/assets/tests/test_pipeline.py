import base64
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PIL import Image
import common
import depth
import pixellab
import sprites


class AssetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.frame = Image.new('RGBA', (8, 8))
        self.frame.putpixel((3, 4), (85, 225, 209, 255))

    def tearDown(self):
        self.temp.cleanup()

    def encoded(self):
        stream = io.BytesIO()
        self.frame.save(stream, format='PNG')
        return {'base64': 'data:image/png;base64,' + base64.b64encode(stream.getvalue()).decode()}

    def test_env_is_data_and_preserves_process(self):
        (self.root / '.env.assets').write_text('ASSET_TEST_KEY="$(echo private) `noop`"\nASSET_TEST_EXISTING=file\n')
        with patch.dict(os.environ, {'ASSET_TEST_EXISTING': 'process'}, clear=True):
            common.load_env(self.root)
            self.assertEqual(os.environ['ASSET_TEST_KEY'], '$(echo private) `noop`')
            self.assertEqual(os.environ['ASSET_TEST_EXISTING'], 'process')

    def test_placeholder_and_name_guards(self):
        with patch.dict(os.environ, {'PIXELLAB_API_KEY': 'YOUR_PRIVATE_KEY'}, clear=True):
            with self.assertRaises(common.PipelineError): common.secret('PIXELLAB_API_KEY')
        for name in ['../escape', '/absolute', 'A bad name', 'x/y']:
            with self.assertRaises(common.PipelineError): common.validate_name(name)

    def test_sprite_preserves_pixels_alpha_alignment_and_no_overwrite(self):
        other = self.frame.copy()
        other.putpixel((4, 4), (255, 100, 80, 255))
        target = sprites.sprite_bundle('test-walk', [self.frame, other], root=self.root)
        atlas = Image.open(target / 'atlas.png')
        self.assertEqual(atlas.crop((1, 1, 9, 9)).tobytes(), self.frame.tobytes())
        self.assertEqual(atlas.crop((11, 1, 19, 9)).tobytes(), other.tobytes())
        resource = (target / 'frames.tres').read_text()
        self.assertIn('Rect2(11, 1, 8, 8)', resource)
        self.assertIn('res://assets/generated/sprites/test-walk/atlas.png', resource)
        with self.assertRaises(common.PipelineError):
            sprites.sprite_bundle('test-walk', [self.frame], root=self.root)

    def test_bad_frames_do_not_publish_partial_assets(self):
        for frames in [[self.frame, Image.new('RGBA', (9, 8))], [Image.new('RGBA', (8, 8), 'white')]]:
            with self.assertRaises(common.PipelineError):
                sprites.sprite_bundle('bad', frames, root=self.root)
        self.assertFalse((self.root / 'assets/generated/sprites/bad').exists())

    def test_atomic_bundle_failure_and_symlink_escape(self):
        with self.assertRaises(RuntimeError):
            with common.output_bundle('sprites', 'fail', self.root) as (stage, target):
                (stage / 'partial.png').write_bytes(b'incomplete')
                raise RuntimeError('fixture')
        self.assertFalse(target.exists())
        outside = self.root / 'outside'
        outside.mkdir()
        other_root = self.root / 'nested'
        other_root.mkdir()
        (other_root / 'assets').symlink_to(outside, target_is_directory=True)
        with self.assertRaises(common.PipelineError):
            with common.output_bundle('sprites', 'escape', other_root): pass

    def test_aseprite_tag_order_and_millisecond_timing(self):
        data = {'frames': [{'duration': 100}, {'duration': 150}, {'duration': 250}],
                'meta': {'frameTags': [{'name': 'walk', 'from': 0, 'to': 2, 'direction': 'pingpong'}]}}
        animation = sprites.aseprite_animations(data)[0]
        self.assertEqual(animation['frames'], [(0, 100), (1, 150), (2, 250), (1, 150)])
        self.assertEqual(animation['fps'], 1000)

    def test_pixel_inline_and_background_results(self):
        for result in [{'image': self.encoded()}, {'last_response': {'images': [self.encoded()]}}]:
            self.assertEqual(pixellab.decode_frames(result)[0].tobytes(), self.frame.tobytes())
        with self.assertRaises(common.PipelineError): pixellab.decode_frames({'images': ['not base64!']})

    def test_pixel_poll_completes_failed_and_timeout_without_post(self):
        calls = []
        states = iter([{'status': 'processing'}, {'status': 'completed', 'last_response': {'images': []}}])
        def fetch(method, path):
            calls.append(method)
            return next(states)
        result = pixellab.poll_job('job-123', 30, fetch=fetch, sleep=lambda _: None)
        self.assertEqual(result['status'], 'completed')
        self.assertEqual(calls, ['GET', 'GET'])
        for status in ['failed', 'processing']:
            with self.assertRaises(common.PipelineError):
                pixellab.poll_job('job-123', 0, fetch=lambda *args: {'status': status})
        with self.assertRaises(common.PipelineError): pixellab.poll_job('../../bad', 1)

    def test_pixel_variant_is_one_candidate_not_an_animation(self):
        receipt = {'name': 'candidate', 'kind': 'sprite', 'variant': 1, 'animation': 'idle',
                   'fps': 10, 'filter': 'nearest', 'provenance': {}}
        with patch.object(pixellab, 'sprite_bundle') as bundle:
            pixellab.finish(receipt, {'images': [self.encoded(), self.encoded()]})
            self.assertEqual(len(bundle.call_args.args[1]), 1)

    def test_returned_frame_count_requires_review_and_preserves_all_frames(self):
        receipt = {'name': 'reviewed', 'kind': 'animation', 'animation': 'carry_e',
                   'fps': 8, 'filter': 'linear', 'provenance': {}, 'expected_frames': 8}
        response = {'last_response': {'images': [self.encoded()] * 9},
                    'usage': {'type': 'generations', 'generations': 6}}
        with patch.object(pixellab, 'sprite_bundle') as bundle:
            with self.assertRaises(common.PipelineError): pixellab.finish(receipt, response)
            bundle.assert_not_called()
            pixellab.finish(receipt, response, accept_returned_frames=True)
            self.assertEqual(len(bundle.call_args.args[1]), 9)
            provenance = bundle.call_args.kwargs['provenance']
            self.assertEqual(provenance['requested_frame_count'], 8)
            self.assertEqual(provenance['returned_frame_count'], 9)
            self.assertTrue(provenance['reviewed_frame_count_override'])
            self.assertEqual(provenance['usage']['generations'], 6)

    def test_paid_submission_marker_blocks_repeat(self):
        args = SimpleNamespace(name='explorer', mode='animation', animation='walk', fps=10,
                               seed=42, wait=0, source=str(self.root / 'source.png'), action='walk',
                               frames=4, filter='nearest')
        self.frame.save(args.source)
        receipt = self.root / 'job.json'
        with patch.dict(os.environ, {'PIXELLAB_API_KEY': 'test-placeholder-for-unit-tests'}), \
             patch.object(pixellab, 'receipt_path', return_value=receipt), \
             patch.object(pixellab, 'request', return_value={'background_job_id': 'job-123'}) as request:
            self.assertIsNone(pixellab.submit(args))
            self.assertEqual(json.loads(receipt.read_text())['job_id'], 'job-123')
            with self.assertRaises(common.PipelineError): pixellab.submit(args)
            self.assertEqual(request.call_count, 1)

    def test_depth_rejects_wrong_size_color_and_flat_maps(self):
        source = self.root / 'source.png'
        self.frame.save(source)
        invalid = [Image.new('L', (7, 8)), Image.new('RGB', (8, 8), (12, 30, 90)), Image.new('L', (8, 8), 120)]
        for index, image in enumerate(invalid):
            path = self.root / f'depth{index}.png'
            image.save(path)
            with self.assertRaises(common.PipelineError):
                depth.depth_bundle(f'invalid{index}', source, path, {}, self.root)

    def test_depth_resource_matches_source_and_near_white_values(self):
        source, depth_path = self.root / 'source.png', self.root / 'depth.png'
        self.frame.save(source)
        image = Image.new('L', (8, 8), 20)
        image.putpixel((4, 4), 230)
        image.save(depth_path)
        target = depth.depth_bundle('valid', source, depth_path, {}, self.root)
        self.assertEqual(Image.open(target / 'depth.png').getpixel((4, 4)), 230)
        self.assertIn('near_is_white = true', (target / 'art.tres').read_text())
        self.assertEqual(json.loads((target / 'manifest.json').read_text())['source_sha256'], common.sha256(source))

    def test_depthflow_exact_multipart_contract_no_manual_boundary_or_secret_receipt(self):
        source, payload = self.root / 'source.png', self.root / 'payload.json'
        self.frame.save(source)
        payload.write_text('{"motion":{"style":"dolly"},"render":{"duration":5}}')
        args = SimpleNamespace(name='cloud', source=str(source), payload_file=str(payload), url_field=None)
        receipt = self.root / 'cloud.json'
        response = SimpleNamespace(status_code=202, headers={'Content-Type': 'application/json'},
                                   json=lambda: {'opaque_provider_job': 'job1', 'echo': 'unit-test-key'})
        with patch.dict(os.environ, {'DEPTHFLOW_API_KEY': 'unit-test-key'}), \
             patch.object(depth, 'DEPTHFLOW_API_ENDPOINT', depth.VERIFIED_DEPTHFLOW_API_ENDPOINT), \
             patch.object(depth, 'cloud_receipt', return_value=receipt), \
             patch('requests.post', return_value=response) as post:
            depth.cloud_submit(args)
            kwargs = post.call_args.kwargs
            self.assertEqual(post.call_args.args[0], 'https://www.depthflow.io/api/ai/depthflow/generate-3d')
            self.assertEqual(kwargs['headers'], {'X-API-Key': 'unit-test-key', 'Accept': 'application/json'})
            self.assertNotIn('Content-Type', kwargs['headers'])
            self.assertEqual(json.loads(kwargs['data']['payload'])['motion']['style'], 'dolly')
            self.assertIn('file', kwargs['files'])
            import requests
            prepared = requests.Request('POST', post.call_args.args[0], headers=kwargs['headers'],
                                        files=kwargs['files'], data=kwargs['data']).prepare()
            self.assertIn('multipart/form-data; boundary=', prepared.headers['Content-Type'])
            self.assertIn(b'name="file"; filename="source.png"', prepared.body)
            self.assertIn(b'name="payload"', prepared.body)
            self.assertNotIn('Authorization', prepared.headers)
            self.assertNotIn('unit-test-key', receipt.read_text())
            with self.assertRaises(common.PipelineError): depth.cloud_submit(args)
            self.assertEqual(post.call_count, 1)

    def test_depthflow_disabled_endpoint_stops_before_keys_or_network(self):
        with patch.object(depth, 'DEPTHFLOW_API_ENDPOINT', None), \
             patch.object(depth, 'secret') as key_lookup, patch('requests.post') as post:
            with self.assertRaisesRegex(common.PipelineError, 'disabled'):
                depth.cloud_submit(SimpleNamespace())
            key_lookup.assert_not_called()
            post.assert_not_called()

    def test_direct_video_receipt_preserves_source_and_payload_provenance(self):
        source, payload = self.root / 'source.png', self.root / 'payload.json'
        self.frame.save(source)
        payload.write_text('{"plan":"free","render":{"duration":5}}')
        args = SimpleNamespace(name='video', source=str(source), payload_file=str(payload), url_field=None)
        receipt = self.root / 'video.json'
        response = SimpleNamespace(status_code=200, headers={'Content-Type': 'video/mp4'},
                                   content=b'\x00\x00\x00\x18ftypmp42')
        with patch.dict(os.environ, {'DEPTHFLOW_API_KEY': 'unit-test-key'}), \
             patch.object(depth, 'DEPTHFLOW_API_ENDPOINT', depth.VERIFIED_DEPTHFLOW_API_ENDPOINT), \
             patch.object(depth, 'work_root', return_value=self.root), \
             patch.object(depth, 'cloud_receipt', return_value=receipt), \
             patch('requests.post', return_value=response):
            depth.cloud_submit(args)
        data = json.loads(receipt.read_text())
        self.assertEqual(data['state'], 'downloaded')
        self.assertEqual(data['source_sha256'], common.sha256(source))
        self.assertEqual(data['payload']['render']['duration'], 5)
        self.assertNotIn('unit-test-key', receipt.read_text())

    def test_depthflow_timeout_preserves_marker_and_prevents_duplicate_submission(self):
        import requests
        source, payload = self.root / 'source.png', self.root / 'payload.json'
        self.frame.save(source)
        payload.write_text('{"motion":{"style":"dolly"},"render":{"duration":5}}')
        args = SimpleNamespace(name='timeout', source=str(source), payload_file=str(payload), url_field=None)
        receipt = self.root / 'timeout.json'
        with patch.dict(os.environ, {'DEPTHFLOW_API_KEY': 'unit-test-key'}), \
             patch.object(depth, 'DEPTHFLOW_API_ENDPOINT', depth.VERIFIED_DEPTHFLOW_API_ENDPOINT), \
             patch.object(depth, 'work_root', return_value=self.root), \
             patch.object(depth, 'cloud_receipt', return_value=receipt), \
             patch('requests.post', side_effect=requests.Timeout('unit-test-key')) as post:
            with self.assertRaisesRegex(common.PipelineError, 'may have succeeded') as failure:
                depth.cloud_submit(args)
            self.assertNotIn('unit-test-key', str(failure.exception))
            self.assertEqual(json.loads(receipt.read_text())['state'], 'submitting')
            self.assertNotIn('unit-test-key', receipt.read_text())
            with self.assertRaisesRegex(common.PipelineError, 'already submitted'):
                depth.cloud_submit(args)
            self.assertEqual(post.call_count, 1)

    def test_depthflow_collection_never_forwards_key_or_follows_redirects(self):
        receipt = self.root / 'result.json'
        receipt.write_text('{"state":"response-saved","response":{"result":{"video":"https://cdn.example.invalid/output.mp4"}}}')
        args = SimpleNamespace(name='result', url_field='result.video')
        response = SimpleNamespace(status_code=200, content=b'\x00\x00\x00\x18ftypmp42')
        with patch.dict(os.environ, {'DEPTHFLOW_API_KEY': 'unit-test-key'}), \
             patch.object(depth, 'work_root', return_value=self.root), \
             patch.object(depth, 'cloud_receipt', return_value=receipt), \
             patch('requests.get', return_value=response) as get:
            output = depth.cloud_collect(args)
            self.assertEqual(output.read_bytes(), response.content)
            self.assertFalse(get.call_args.kwargs['allow_redirects'])
            self.assertNotIn('headers', get.call_args.kwargs)
            self.assertEqual(json.loads(receipt.read_text())['state'], 'downloaded')

    def test_provider_errors_never_print_body_or_key(self):
        response = SimpleNamespace(status_code=401, text='unit-test-key secret response')
        with patch.dict(os.environ, {'PIXELLAB_API_KEY': 'unit-test-key'}), patch('requests.request', return_value=response):
            with self.assertRaises(common.PipelineError) as captured: pixellab.request('POST', '/create-image-pixen', {})
        self.assertNotIn('unit-test-key', str(captured.exception))
        self.assertNotIn('secret response', str(captured.exception))

    def test_godot_import_diagnostics_fail_even_with_exit_zero(self):
        response = SimpleNamespace(returncode=0, stdout='', stderr='SCRIPT ERROR: fixture')
        with patch('subprocess.run', return_value=response), patch('builtins.print'):
            with self.assertRaises(common.PipelineError):
                common.run_local(['godot'], cwd=self.root, godot_check=True)

    def test_local_tool_does_not_inherit_keys(self):
        with patch.dict(os.environ, {'PIXELLAB_API_KEY': 'private', 'DEPTHFLOW_API_KEY': 'private'}), \
             patch('subprocess.run', return_value=SimpleNamespace(returncode=0)) as run:
            common.run_local(['tool'], cwd=self.root)
            self.assertNotIn('PIXELLAB_API_KEY', run.call_args.kwargs['env'])
            self.assertNotIn('DEPTHFLOW_API_KEY', run.call_args.kwargs['env'])


if __name__ == '__main__':
    unittest.main()
