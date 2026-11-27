#!/bin/zsh
set -eu

project=${0:A:h:h:h}
if [[ $# != 5 ]]; then
  print -u2 'Usage: package-stable.sh STABLE_APP TU3_GAME_APP VERIFIED_TITLE_UPDATE REXGLUE_SDK OUTPUT_DIR'
  exit 2
fi
stable=${1:A}
candidate=${2:A}
title_update=${3:A}
sdk=${4:A}
output=${5:A}
app="$output/GRFS Recompiled.app"
resources="$app/Contents/Resources"
runtime="$resources/Game.app/Contents/MacOS"
launcher="$project/launcher"
[[ ! -e "$app" ]]

# Allow only the verified TU3 inventory, never base-game or DLC files.
(cd "$title_update" && shasum -a 256 -c "$project/tu3/update-assets.sha256")
mkdir -p "$output"
cp -cR "$stable" "$app"
cp "$launcher/compatible-game.json" "$resources/compatible-game.json"
mkdir "$resources/TU3"
while read -r digest file; do
  mkdir -p "$resources/TU3/${file:h}"
  cp "$title_update/$file" "$resources/TU3/$file"
done < "$project/tu3/update-assets.sha256"

for file in grfs libgrfs_AICLASS_X360_F.dylib; do
  cp "$candidate/Contents/MacOS/$file" "$runtime/$file"
done

swiftc "$launcher"/{main,Launcher,ExperimentalGraphics,Updater,LauncherTheme,LegacyBackups,RestartRequest,ShaderPreparation,TitleUpdate,DLCInstallation}.swift \
  -framework AppKit -framework CryptoKit -module-cache-path /private/tmp/grfs-swift-cache \
  -o "$app/Contents/MacOS/GRFSLauncher"

clang++ -std=c++23 -O2 -I"$sdk/include" -I"$sdk/thirdparty/fmt/include" \
  -I"$sdk/thirdparty/spdlog/include" -I"$sdk/thirdparty/simde" \
  "$project/tu3/install-dlc.cpp" -L"$runtime" -lrexruntime -Wl,-rpath,@loader_path \
  -o "$runtime/InstallDLC"
codesign --force --sign - "$runtime/InstallDLC"

python3 - "$launcher/version.json" "$app/Contents/Info.plist" "$resources/Game.app/Contents/Info.plist" <<'PY'
import json
import plistlib
import sys
from pathlib import Path

version = json.loads(Path(sys.argv[1]).read_text())
for name in sys.argv[2:]:
    path = Path(name)
    info = plistlib.loads(path.read_bytes())
    info.update(CFBundleShortVersionString=version["version"], CFBundleVersion=str(version["build"]),
                LSMinimumSystemVersion=version["minimumSystem"], LSMultipleInstancesProhibited=True)
    path.write_bytes(plistlib.dumps(info))
PY

codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
archive="$output/GRFS-Recompiled-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
python3 - "$launcher/version.json" "$archive" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

version = json.loads(Path(sys.argv[1]).read_text())
archive = Path(sys.argv[2])
with archive.open("rb") as stream:
    checksum = hashlib.file_digest(stream, "sha256").hexdigest()
manifest = dict(
    version=version["version"],
    build=version["build"],
    minimumSystem=version["minimumSystem"],
    url=f"https://github.com/alex-stampede/GRFS-Recomp/releases/download/{version['tag']}/{archive.name}",
    sha256=checksum,
    size=archive.stat().st_size,
    notes="Includes Title Update 3. Install DLC from a local folder using the launcher, then choose Play Game.",
)
archive.with_name("update-payload.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY
