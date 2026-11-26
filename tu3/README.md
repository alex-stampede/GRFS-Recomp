# TU3 integration for Xbox 360 media 2DF41A75

This worktree is based on v3.1.1. The title-specific ReXGlue manifest records TU3 entry points and the module registry for Default and AICLASS. Apply the firing-range guard after code generation using apply-guard.py alongside the generated directory.

The private build and test workspace is the parent of this worktree. There, prepare-tu3.py validates an original disc and update package, stages the verified sibling XEXP files for ReXGlue, and retains the non-executable files on update:. No game files, generated title code, title update files or save data belong in this worktree.
