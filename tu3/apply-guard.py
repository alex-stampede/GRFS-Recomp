from pathlib import Path


root = Path(__file__).resolve().parent
anchor = 'DEFINE_REX_FUNC(sub_82BAD718) {\n\tREX_FUNC_PROLOGUE();'
guard = '''
    // Preserve the 3.1.1 firing-range guard on TU3's relocated routine.
    if (!ctx.r3.u32 || !ctx.r4.u32) {
        ctx.r3.u64 = 0;
        return;
    }'''
[path] = [p for p in (root / 'generated/default').glob('*.cpp') if anchor in p.read_text()]
source = path.read_text()
if anchor + guard not in source:
    path.write_text(source.replace(anchor, anchor + guard, 1))
