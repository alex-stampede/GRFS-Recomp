#!/usr/bin/env python3
"""Build a local macOS ARM64 launcher; never package game assets."""
from pathlib import Path
import subprocess, shutil, plistlib, os, json, hashlib
from build_icon import build_icon
root=Path(__file__).resolve().parent
project=root.parent
output=Path(os.environ.get('GRFS_OUTPUT_DIR',root/'dist'))
app=output/'GRFS Recompiled.app'
if app.exists(): shutil.rmtree(app)
mac=app/'Contents/MacOS'; resources=app/'Contents/Resources'
game_app=resources/'Game.app'; runtime=game_app/'Contents/MacOS'; game_resources=game_app/'Contents/Resources'
mac.mkdir(parents=True); runtime.mkdir(parents=True); game_resources.mkdir(parents=True)
base=Path(os.environ.get('GRFS_RUNTIME_DIR',root/'runtime'))
version=json.loads((root/'version.json').read_text())
if not (base/'grfs').exists(): raise SystemExit('Set GRFS_RUNTIME_DIR to a compatible compiled runtime directory (see README).')
subprocess.run(['swiftc',str(root/'main.swift'),str(root/'Launcher.swift'),str(root/'Updater.swift'),str(root/'LauncherTheme.swift'),str(root/'LegacyBackups.swift'),'-o',str(mac/'GRFSLauncher'),'-framework','AppKit','-framework','CryptoKit','-module-cache-path','/private/tmp/grfs-swift-cache'],check=True)
for name in ['grfs','librexruntime.dylib','librexgpu-xenos.dylib','libgrfs_AICLASS_X360_F.dylib','libTracyClient.dylib']:
    shutil.copy2(base/name,runtime/name)
shutil.copytree(base/'vulkan',runtime/'vulkan')
subprocess.run(['clang','-dynamiclib','-fobjc-arc',str(root/'GameTitle.m'),str(root/'FullscreenDiagnostics.m'),'-framework','QuartzCore','-framework','AppKit','-o',str(runtime/'libGRFSWindowTitle.dylib')],check=True)
subprocess.run(['swiftc',str(root/'UpdateHelper.swift'),'-o',str(resources/'ApplyUpdate'),'-framework','AppKit','-module-cache-path','/private/tmp/grfs-swift-cache'],check=True)
for name in ['compatible-game.json','required-files.json','update-public-key.txt']: shutil.copy2(root/name,resources/name)
icon=Path(os.environ.get('GRFS_ICON_FILE',root/'GRFS.icns'))
if 'GRFS_ICON_FILE' not in os.environ:
    build_icon(root/'Resources/DockIcon.png', icon)
if icon.exists():
    shutil.copy2(icon,resources/'GRFS.icns')
    shutil.copy2(icon,game_resources/'GRFS.icns')
else:
    raise SystemExit('GRFS_ICON_FILE must point to a valid .icns so both apps have a Dock icon.')
game_info=dict(CFBundleIdentifier='local.grfs.game',CFBundleName='Ghost Recon Future Soldier Recomp',CFBundleDisplayName='Ghost Recon Future Soldier Recomp',CFBundleExecutable='grfs',CFBundleIconFile='GRFS.icns',CFBundlePackageType='APPL',CFBundleShortVersionString=version['version'],CFBundleVersion=str(version['build']),LSMinimumSystemVersion=version['minimumSystem'],NSHighResolutionCapable=True,LSMultipleInstancesProhibited=True)
game_info.update(LSApplicationCategoryType='public.app-category.games', LSSupportsGameMode=True, GCSupportsGameMode=True)
with (game_app/'Contents/Info.plist').open('wb') as f: plistlib.dump(game_info,f)
shutil.copy2(root/'Resources/Background.jpg',resources/'Background.jpg')
for destination in [resources, game_resources]:
    shutil.copy2(root/'Resources/DockIcon.png', destination/'DockIcon.png')
licenses=project/'THIRD_PARTY_LICENSES'
if licenses.exists(): shutil.copytree(licenses,resources/'Licenses')
info=dict(CFBundleDevelopmentRegion='en',CFBundleLocalizations=['en'],CFBundleIdentifier='local.grfs.launcher',CFBundleName='GRFS Recompiled',CFBundleDisplayName='Ghost Recon Future Soldier',CFBundleExecutable='GRFSLauncher',CFBundleIconFile='GRFS.icns',CFBundlePackageType='APPL',CFBundleShortVersionString=version['version'],CFBundleVersion=str(version['build']),LSMinimumSystemVersion=version['minimumSystem'],NSHighResolutionCapable=True)
info.update(LSApplicationCategoryType='public.app-category.games', LSSupportsGameMode=True, GCSupportsGameMode=True)
with (app/'Contents/Info.plist').open('wb') as f: plistlib.dump(info,f)
# Ad-hoc signing is for local testing, not Apple notarization.
subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
archive=output/'GRFS-Recompiled-macOS-arm64.zip'
archive.unlink(missing_ok=True)
subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(app),str(archive)],check=True)
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(output/'SHA256SUMS.txt').write_text(digest+'  '+archive.name+'\n')
payload=dict(version=version['version'],build=version['build'],minimumSystem=version['minimumSystem'],url='https://github.com/alex-stampede/GRFS-Recomp/releases/download/'+version['tag']+'/'+archive.name,sha256=digest,size=archive.stat().st_size,notes='Transparent GRFS Dock icon for the launcher and game. Starts in native macOS fullscreen and declares Game Mode support; macOS controls activation and remembers your preference. The v0.10.0.4 game/runtime/GPU code and graphics configuration are preserved; no performance or geometry experiments are included.')
(output/'update-payload.json').write_text(json.dumps(payload,ensure_ascii=False,sort_keys=True,indent=2)+'\n')
print(app)
