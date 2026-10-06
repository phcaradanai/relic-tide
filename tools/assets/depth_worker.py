"""Run inside the user's DA-V2 environment; do not change its checkout."""
import argparse
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--checkout', required=True)
    parser.add_argument('--checkpoint', required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--input-size', type=int, default=518)
    parser.add_argument('--device', choices=['auto', 'cpu', 'mps', 'cuda'], default='auto')
    args = parser.parse_args()
    import cv2
    import numpy as np
    import torch
    sys.path.insert(0, str(Path(args.checkout).resolve()))
    from depth_anything_v2.dpt import DepthAnythingV2

    torch.set_num_threads(4)
    device = args.device
    if device == 'auto':
        device = 'cuda' if torch.cuda.is_available() else 'mps' if torch.backends.mps.is_available() else 'cpu'
    source = cv2.imread(args.source)
    if source is None:
        raise ValueError('Input image cannot be decoded.')
    # Small is the user's installed model and the upstream Apache-2.0 checkpoint.
    model = DepthAnythingV2(encoder='vits', features=64, out_channels=[48, 96, 192, 384])
    model.load_state_dict(torch.load(args.checkpoint, map_location='cpu', weights_only=True))
    model = model.to(device).eval()
    with torch.inference_mode():
        depth = model.infer_image(source, args.input_size)
    if not np.isfinite(depth).all():
        raise ValueError('Depth prediction contains invalid values.')
    span = float(depth.max() - depth.min())
    if span <= 1e-8:
        raise ValueError('Depth prediction is flat; cannot create a meaningful parallax map.')
    # Upstream relative inverse depth: larger values are nearer. Keep near-white.
    normalized = np.rint((depth - depth.min()) / span * 255).astype(np.uint8)
    if not cv2.imwrite(args.output, normalized):
        raise OSError('Depth output could not be written.')
    print(f'Depth map ready ({normalized.shape[1]}x{normalized.shape[0]}, {device}).')


if __name__ == '__main__':
    main()
