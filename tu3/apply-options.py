"""Restore the PC options bridge after generating the TU3 AICLASS module."""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("generated_aiclass", type=Path)
    args = parser.parse_args()
    signature = "DEFINE_REX_FUNC(sub_884FA3C0) {"
    # The ScreenLoaded match, r3 payload and guest string-length loop.
    anchor = (
        "\tif (!ctx.cr6.eq) goto loc_884FA520;\n"
        "\t// lis r10,-30592\n"
        "\tctx.r10.s64 = -2004877312;\n"
        "\t// subf r11,r3,r11\n"
        "\tctx.r11.u64 = ctx.r11.u64 - ctx.r3.u64;\n"
        "\t// addi r9,r11,-1\n"
        "\tctx.r9.s64 = ctx.r11.s64 + -1;\n"
    )
    bridge = (
        "\t// Forward the native screen name, excluding its terminator.\n"
        '\trex::cvar::InvokeCommand("grfs_notify_screen",\n'
        "\t    std::string_view(reinterpret_cast<const char*>(base + ctx.r3.u32), ctx.r9.u32));\n"
    )
    for path in sorted(args.generated_aiclass.glob("grfs_recomp.*.cpp")):
        source = path.read_text()
        if signature not in source:
            continue
        begin = source.index(signature)
        end = source.find("\nDEFINE_REX_FUNC(", begin + len(signature))
        end = len(source) if end == -1 else end
        function = source[begin:end]
        if function.count(anchor) != 1:
            raise SystemExit(f"Unexpected TU3 ScreenLoaded sequence in {path}")
        if anchor + bridge not in function:
            includes = "#include <rex/cvar.h>\n#include <string_view>\n"
            path.write_text(includes + source[:begin] + function.replace(anchor, anchor + bridge) + source[end:])
        print(path)
        return
    raise SystemExit("TU3 ScreenLoaded callback sub_884FA3C0 was not found")


if __name__ == "__main__":
    main()
