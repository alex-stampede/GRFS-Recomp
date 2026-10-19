#!/usr/bin/env python3
"""Build a local macOS ARM64 launcher; never package game assets."""
from pathlib import Path
import subprocess, shutil, plistlib, os, json, hashlib
root=Path(__file__).resolve().parent
project=root.parent
app=root/'dist/GRFS Recompiled.app'
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
if icon.exists():
    shutil.copy2(icon,resources/'GRFS.icns')
    shutil.copy2(icon,game_resources/'GRFS.icns')
else:
    raise SystemExit('GRFS_ICON_FILE must point to a valid .icns so both apps have a Dock icon.')
game_info=dict(CFBundleIdentifier='local.grfs.game',CFBundleName='Ghost Recon Future Soldier Recomp',CFBundleDisplayName='Ghost Recon Future Soldier Recomp',CFBundleExecutable='grfs',CFBundleIconFile='GRFS.icns',CFBundlePackageType='APPL',CFBundleShortVersionString=version['version'],CFBundleVersion=str(version['build']),LSMinimumSystemVersion=version['minimumSystem'],NSHighResolutionCapable=True,LSMultipleInstancesProhibited=True)
with (game_app/'Contents/Info.plist').open('wb') as f: plistlib.dump(game_info,f)
shutil.copy2(root/'Resources/Background.jpg',resources/'Background.jpg')
licenses=project/'THIRD_PARTY_LICENSES'
if licenses.exists(): shutil.copytree(licenses,resources/'Licenses')
info=dict(CFBundleDevelopmentRegion='en',CFBundleLocalizations=['en'],CFBundleIdentifier='local.grfs.launcher',CFBundleName='GRFS Recompiled',CFBundleDisplayName='Ghost Recon Future Soldier',CFBundleExecutable='GRFSLauncher',CFBundleIconFile='GRFS.icns',CFBundlePackageType='APPL',CFBundleShortVersionString=version['version'],CFBundleVersion=str(version['build']),LSMinimumSystemVersion=version['minimumSystem'],NSHighResolutionCapable=True)
with (app/'Contents/Info.plist').open('wb') as f: plistlib.dump(info,f)
# Ad-hoc signing is for local testing, not Apple notarization.
subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
archive=root/'dist/GRFS-Recompiled-macOS-arm64.zip'
archive.unlink(missing_ok=True)
subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(app),str(archive)],check=True)
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(root/'dist/SHA256SUMS.txt').write_text(digest+'  '+archive.name+'\n')
payload=dict(version=version['version'],build=version['build'],minimumSystem=version['minimumSystem'],url='https://github.com/alex-stampede/GRFS-Recomp/releases/download/'+version['tag']+'/'+archive.name,sha256=digest,size=archive.stat().st_size,notes='English launcher and update dialogs, a new GRFS design, and a macOS Metal swapchain recreation fix for fullscreen transitions. Existing game files, saves and shader storage are preserved.')
(root/'dist/update-payload.json').write_text(json.dumps(payload,ensure_ascii=False,sort_keys=True,indent=2)+'\n')
print(app)
