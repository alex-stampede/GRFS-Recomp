#!/bin/zsh
set -eu

launcher_dir=${0:A:h}
if [[ $# != 4 ]]; then
  print -u2 'Usage: package.sh CANDIDATE_GAME_APP REFERENCE_LAUNCHER_APP REXGLUE_SDK OUTPUT_DIR'
  exit 2
fi
candidate=${1:A}
reference=${2:A}
sdk=${3:A}
destination=${4:A}
app="$destination/GRFS Recompiled TU3 Preview.app"
resources="$app/Contents/Resources"
runtime="$resources/Game.app/Contents/MacOS"
[[ ! -e "$app" ]]
mkdir -p "$app/Contents/MacOS" "$resources"
cp -cR "$candidate" "$resources/Game.app"
cp -R "$reference/Contents/Resources/Licenses" "$resources/"
cp "$reference/Contents/Resources/GRFS.icns" "$resources/"

swiftc "$launcher_dir/main.swift" "$launcher_dir/RestartRequest.swift" \
  -framework AppKit -module-cache-path /private/tmp/grfs-tu3-preview-module-cache \
  -o "$app/Contents/MacOS/GRFSTU3Launcher"

for component in ExtractTU InstallDLC; do
  if [[ "$component" == ExtractTU ]]; then
    source_file="$launcher_dir/ExtractTU.cpp"
  else
    source_file="$launcher_dir/../install-dlc.cpp"
  fi
  clang++ -std=c++23 -O2 -I"$sdk/include" -I"$sdk/thirdparty/fmt/include" \
    -I"$sdk/thirdparty/spdlog/include" -I"$sdk/thirdparty/simde" \
    "$source_file" -L"$runtime" -lrexruntime -Wl,-rpath,@loader_path -o "$runtime/$component"
  codesign --force --sign - "$runtime/$component"
done

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.grfs.launcher.tu3.preview</string>
<key>CFBundleName</key><string>GRFS Recompiled TU3 Preview</string>
<key>CFBundleDisplayName</key><string>GRFS Recompiled TU3 Preview</string>
<key>CFBundleExecutable</key><string>GRFSTU3Launcher</string>
<key>CFBundleIconFile</key><string>GRFS.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>3.1.2</string>
<key>CFBundleVersion</key><string>2026112602</string>
<key>LSMinimumSystemVersion</key><string>27.2</string>
<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -lint "$app/Contents/Info.plist"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$destination/GRFS-Recompiled-3.1.2-TU3-macOS-arm64.zip"
