"""Paid pickup resumes must reuse the existing group and never repeat a POST."""
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import character_production as managed
import holding_production as holding
from common import PipelineError,write_json


class HoldingReceiptTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)
        self.jobs=self.root/'receipts';self.jobs.mkdir()
        inputs=self.root/'.asset-work/characters/explorer-holding-v2/pickup-inputs';inputs.mkdir(parents=True)
        for angle in ('south','south-west'):
            for side in ('start','end'):
                Image.new('RGBA',(4,4),(10,20,30,0)).save(inputs/f'pickup_relic-{angle}-{side}.png')

    def tearDown(self):self.temp.cleanup()

    def test_added_direction_extends_known_group_without_repeating_accepted_job(self):
        with patch.object(managed,'folder',return_value=self.jobs),patch.object(holding,'ROOT',self.root),patch.object(holding,'character_id',return_value='test-character'),patch.object(managed,'request',return_value={'animation_group_id':'existing-group','background_job_ids':['known-job']}) as api:
            holding.animate('pickup_relic','south')
            holding.animate('pickup_relic','south')
            self.assertEqual(api.call_count,1)
            holding.animate('pickup_relic','south-west')
            self.assertEqual(api.call_count,2)
            payload=api.call_args.args[2]
            self.assertEqual(payload['animation_group_id'],'existing-group')
            self.assertEqual(payload['directions'],['south-west'])
            self.assertIn('custom_start_frame',payload)
            self.assertIn('end_frame',payload)

    def test_ambiguous_previous_direction_blocks_new_paid_submissions(self):
        write_json(self.jobs/'holding-v2-pickup_relic-south.json',{'state':'submitting'})
        with patch.object(managed,'folder',return_value=self.jobs),patch.object(holding,'ROOT',self.root),patch.object(managed,'request') as api:
            with self.assertRaises(PipelineError):holding.animate('pickup_relic','south-west')
            api.assert_not_called()


if __name__=='__main__':unittest.main()
