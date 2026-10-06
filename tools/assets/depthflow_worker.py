"""Optional DepthFlow 1.0.1 Python API preview. Separate env from DA-V2."""
import argparse
import math


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--image', required=True)
    parser.add_argument('--depth', required=True)
    parser.add_argument('--output')
    parser.add_argument('--seconds', type=float, default=5)
    parser.add_argument('--fps', type=float, default=30)
    parser.add_argument('--amplitude', type=float, default=0.01)
    args = parser.parse_args()
    from depthflow.scene import DepthScene
    from importlib.metadata import version
    if version('depthflow') != '1.0.1':
        raise RuntimeError('This wrapper targets depthflow==1.0.1; install the pinned optional requirements.')

    class Preview(DepthScene):
        def update(self):
            self.state.offset = (args.amplitude * math.sin(self.cycle), 0.0)

    # GLFW works with macOS OpenGL; headless EGL is unavailable on macOS.
    scene = Preview(backend='glfw')
    scene.input(image=args.image, depth=args.depth)
    scene.main(output=args.output, time=args.seconds, fps=args.fps, width=None, height=None)


if __name__ == '__main__':
    main()
