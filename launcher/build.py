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
subprocess.run(['swiftc',str(root/'main.swift'),str(root/'Launcher.swift'),str(root/'Updater.swift'),str(root/'LauncherTheme.swift'),str(root/'LegacyBackups.swift'),str(root/'RestartRequest.swift'),'-o',str(mac/'GRFSLauncher'),'-framework','AppKit','-framework','CryptoKit','-module-cache-path','/private/tmp/grfs-swift-cache'],check=True)
for name in ['grfs','librexruntime.dylib','librexgpu-xenos.dylib','libgrfs_AICLASS_X360_F.dylib','libTracyClient.dylib']:
    shutil.copy2(base/name,runtime/name)
if os.environ.get('GRFS_GPU_FILE'):
    shutil.copy2(Path(os.environ['GRFS_GPU_FILE']),runtime/'librexgpu-xenos.dylib')
shutil.copytree(base/'vulkan',runtime/'vulkan')
subprocess.run(['clang++','-x','objective-c++','-std=c++17','-dynamiclib','-fobjc-arc',str(root/'GameTitle.m'),str(root/'FullscreenDiagnostics.m'),str(root/'PerformanceHUD.mm'),'-framework','QuartzCore','-framework','AppKit','-o',str(runtime/'libGRFSWindowTitle.dylib')],check=True)
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
payload=dict(version=version['version'],build=version['build'],minimumSystem=version['minimumSystem'],url='https://github.com/alex-stampede/GRFS-Recomp/releases/download/'+version['tag']+'/'+archive.name,sha256=digest,size=archive.stat().st_size,notes='Simplifies control flow in three exact pixel shader variants and groups compatible independent depth/color clears using explicit dynamic-rendering attachments, including guest 10-bit color. Tested M3 scene was reported free of visual bugs; no controlled FPS uplift or guaranteed 30 FPS is claimed. Keeps mip0, MSAA, F5, fullscreen/Game Mode, controls, saves and installer. Uses separate CacheCombinedFlowV1; first-use shader compilation may still hitch.')
(output/'update-payload.json').write_text(json.dumps(payload,ensure_ascii=False,sort_keys=True,indent=2)+'\n')
print(app)
