#!/usr/bin/env python3
"""Patch .cj files: rename backing vars that conflict with func names.

Kotlin allows `var startPos = 0` + `fun startPos(): Int` in the same class.
Cangjie flat namespace forbids it. Fix: rename var to `_<name>`.
"""

import re
import sys
import os

PATCHES = {
    "Safelist.cj": [("preserveRelativeLinks", "_preserveRelativeLinks")],
    "StreamParser.cj": [
        ("document", "_document"),
        ("next", "_next"),
        ("tail", "_tail"),
    ],
    "StructuralEvaluator.cj": [("wantsNodes", "_wantsNodes")],
    "ThreadLocal.cj": [("it", "_it")],
    "Token.cj": [
        ("startPos", "_startPos"),
        ("endPos", "_endPos"),
    ],
}

def patch_file(filepath, renames):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    original = content

    for old_name, new_name in renames:
        # Pattern 1: var declaration `var oldName = ...` or `var oldName: Type = ...`
        # Only at class level (indented by 4 spaces)
        # Replace: var oldName -> var newName
        content = re.sub(
            rf"(\bvar\s+){re.escape(old_name)}(\s*[=:])",
            rf"\1{new_name}\2",
            content,
        )

        # Pattern 2: let declaration `let oldName = ...` or `let oldName: Type = ...`
        content = re.sub(
            rf"(\blet\s+){re.escape(old_name)}(\s*[=:])",
            rf"\1{new_name}\2",
            content,
        )

        # Pattern 3: References like `return oldName`, `oldName =`, `oldName)`, `oldName}`, etc.
        # But NOT: `func oldName(` or `.oldName(` (these are function signatures/calls)
        # Strategy: replace all occurrences NOT preceded by `func ` or `.`
        # More precisely: replace word-bounded occurrences that are NOT the func declaration

        # Replace in non-declaration contexts:
        # - `= oldName` -> `= newName`
        content = re.sub(
            rf"(?<!\w)(?<!func\s)(?<!\.){re.escape(old_name)}(?!\s*\()",
            new_name,
            content,
        )
        # Also replace `oldName =` (assignment to the var, not func call which would be `oldName(`)
        content = re.sub(
            rf"(?<!\w)(?<!func\s)(?<!\.){re.escape(old_name)}(\s*=)",
            rf"{new_name}\1",
            content,
        )
        # Replace `return oldName`
        content = re.sub(
            rf"return\s+{re.escape(old_name)}\b",
            f"return {new_name}",
            content,
        )
        # Replace `this.oldName` when referencing the var
        content = re.sub(
            rf"this\.{re.escape(old_name)}\b",
            f"this.{new_name}",
            content,
        )

    if content != original:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        return True
    return False

def main():
    src_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    for filename, renames in PATCHES.items():
        filepath = os.path.join(src_dir, filename)
        if os.path.exists(filepath):
            changed = patch_file(filepath, renames)
            print(f"{'PATCHED' if changed else 'UNCHANGED'}: {filename}")
        else:
            print(f"MISSING: {filename}")

if __name__ == "__main__":
    main()
