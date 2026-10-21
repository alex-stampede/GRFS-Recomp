"""Package the transparent Dock artwork as a Finder/application ICNS icon."""
from pathlib import Path
import subprocess
import struct
import tempfile


def build_icon(source: Path, output: Path):
    with tempfile.TemporaryDirectory(prefix='grfs-icon-') as temporary:
        iconset = Path(temporary) / 'GRFS.iconset'
        iconset.mkdir()
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                pixels = size * scale
                suffix = '@2x' if scale == 2 else ''
                destination = iconset / f'icon_{size}x{size}{suffix}.png'
                subprocess.run(['sips', '-z', str(pixels), str(pixels), str(source),
                                '--out', str(destination)], check=True,
                               stdout=subprocess.DEVNULL)
        # Modern ICNS elements contain PNG data, retaining the original alpha.
        types = {(16, 1): b'icp4', (32, 1): b'icp5', (128, 1): b'ic07',
                 (256, 1): b'ic08', (512, 1): b'ic09', (16, 2): b'ic11',
                 (32, 2): b'ic12', (128, 2): b'ic13', (256, 2): b'ic14',
                 (512, 2): b'ic10'}
        chunks = []
        for (size, scale), kind in types.items():
            suffix = '@2x' if scale == 2 else ''
            png = (iconset / f'icon_{size}x{size}{suffix}.png').read_bytes()
            chunks.append(kind + struct.pack('>I', len(png) + 8) + png)
        payload = b''.join(chunks)
        output.write_bytes(b'icns' + struct.pack('>I', len(payload) + 8) + payload)


if __name__ == '__main__':
    root = Path(__file__).resolve().parent
    build_icon(root / 'Resources/DockIcon.png', root / 'GRFS.icns')
