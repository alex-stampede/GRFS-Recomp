"""Check packaged macOS identity, icons, linkage layout, and untouched game code."""
from pathlib import Path
import plistlib,hashlib,subprocess,os,tempfile,shutil
root=Path(__file__).resolve().parent
app=Path(os.environ.get('GRFS_OUTPUT_DIR',root/'dist'))/'GRFS Recompiled.app'
game=app/'Contents/Resources/Game.app'
load=lambda p:plistlib.loads(p.read_bytes())
outer=load(app/'Contents/Info.plist');inner=load(game/'Contents/Info.plist')
assert outer['CFBundleIdentifier']=='local.grfs.launcher'
assert outer['CFBundleDevelopmentRegion']=='en'
assert (app/'Contents/Resources/Background.jpg').read_bytes()[:2]==b'\xff\xd8'
assert inner['CFBundleIdentifier']=='local.grfs.game'
icd=game/'Contents/MacOS/vulkan/share/vulkan/icd.d/MoltenVK_icd.json'
import json
assert icd.exists(),'Missing packaged Vulkan driver manifest'
driver=json.loads(icd.read_text())['ICD']['library_path']
assert (icd.parent/driver).resolve().is_file(),'Packaged driver manifest points to a missing library'
assert inner['CFBundleExecutable']=='grfs'
assert inner['CFBundleName']=='Ghost Recon Future Soldier Recomp'
assert outer['CFBundleVersion']==inner['CFBundleVersion']
for info in [outer, inner]:
    assert info['LSApplicationCategoryType']=='public.app-category.games'
    assert info['LSSupportsGameMode'] is True
    assert info['GCSupportsGameMode'] is True
for bundle in [app,game]:
    icon=bundle/'Contents/Resources/GRFS.icns'
    assert icon.exists() and icon.read_bytes()[:4]==b'icns'
    assert (bundle/'Contents/Resources/DockIcon.png').read_bytes()==(root/'Resources/DockIcon.png').read_bytes()
assert (app/'Contents/Resources/GRFS.icns').read_bytes()==(game/'Contents/Resources/GRFS.icns').read_bytes()
base=Path(os.environ['GRFS_RUNTIME_DIR'])
# The executable is ad-hoc re-signed during packaging; compare Mach-O code sections,
# not embedded signatures, by checking the __TEXT section dump.
for name in ['grfs','librexruntime.dylib','librexgpu-xenos.dylib','libgrfs_AICLASS_X360_F.dylib','libTracyClient.dylib']:
    output=lambda p:subprocess.check_output(['otool','-t',str(p)]).split(b'\n',1)[1]
    expected=Path(os.environ['GRFS_GPU_FILE']) if name=='librexgpu-xenos.dylib' and os.environ.get('GRFS_GPU_FILE') else base/name
    assert output(expected)==output(game/'Contents/MacOS'/name),name
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
# Exercise Foundation's real main-bundle resolution for the nested executable layout.
with tempfile.TemporaryDirectory() as temporary:
    temp=Path(temporary);probe=temp/'Game.app/Contents/MacOS/grfs'
    probe.parent.mkdir(parents=True);shutil.copy2(game/'Contents/Info.plist',probe.parent.parent/'Info.plist')
    source=temp/'probe.m'
    source.write_text('#import <Foundation/Foundation.h>\nint main(){@autoreleasepool { return ![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"local.grfs.game"]; }}\n')
    subprocess.run(['clang',str(source),'-framework','Foundation','-o',str(probe)],check=True)
    subprocess.run([str(probe)],check=True)
print('PASS: game app identity, matching Dock icons, nested bundle resolution, unchanged runtime code and signature')
