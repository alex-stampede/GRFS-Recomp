from pathlib import Path
import tempfile,struct,subprocess
binary='/private/tmp/grfs-launcher-build'
with tempfile.TemporaryDirectory() as temp:
    root=Path(temp)
    def make(name='hello.bin', bad=False, partition=0):
        data=bytearray(partition+40*2048)
        d=partition+32*2048; data[d:d+20]=b'MICROSOFT*XBOX*MEDIA'
        struct.pack_into('<II',data,d+20,33,2048)
        p=partition+33*2048
        struct.pack_into('<HHIIBB',data,p,0,0,99 if bad else 34,5,0,len(name))
        data[p+14:p+14+len(name)]=name.encode()
        data[partition+34*2048:partition+34*2048+5]=b'hello'
        iso=root/'test.iso';iso.write_bytes(data);return iso
    iso=make(); result=subprocess.run([binary,'--inspect-iso',str(iso)],capture_output=True,text=True)
    assert result.returncode==0 and 'hello.bin' in result.stdout,result
    out=root/'out';subprocess.run([binary,'--extract-iso',str(iso),str(out)],check=True)
    assert (out/'hello.bin').read_bytes()==b'hello'
    for name,bad in [('../evil',False),('hello.bin',True)]:
        result=subprocess.run([binary,'--inspect-iso',str(make(name,bad))],capture_output=True)
        assert result.returncode!=0
    iso.write_bytes(b'truncated');assert subprocess.run([binary,'--inspect-iso',str(iso)],capture_output=True).returncode!=0
print('PASS: valid XISO, exact extraction, path traversal, out-of-bounds and truncated input')
