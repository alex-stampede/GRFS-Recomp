#!/usr/bin/env python3
"""Package the standard TU3 launcher from verified release inputs."""
import os
from pathlib import Path
import subprocess

launcher = Path(__file__).resolve().parent
inputs = ("GRFS_STABLE_APP", "GRFS_TU3_GAME_APP", "GRFS_TU3_ASSETS", "GRFS_SDK_DIR")
missing = [name for name in inputs if not os.environ.get(name)]
if missing:
    raise SystemExit(f"Set {', '.join(missing)}. See tu3/README.md for the expected inputs.")

subprocess.run(
    ["zsh", str(launcher.parent / "tu3/launcher/package-stable.sh"),
     *(os.environ[name] for name in inputs), os.environ.get("GRFS_OUTPUT_DIR", str(launcher / "dist"))],
    check=True,
)
