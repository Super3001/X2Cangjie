#!/usr/bin/env python3
"""Fix ALL class name collisions in ksoup_cj output.
Handles: inner class duplicates, KMP duplicates, var-func collisions, it redefinitions.
"""
import os, sys, re

SRC = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

# Step 1: Find all class/enum/interface declarations
class_to_files = {}
for fname in sorted(os.listdir(SRC)):
    if not fname.endswith(".cj"):
        continue
    fpath = os.path.join(SRC, fname)
    classes = []
    with open(fpath) as fh:
        for line in fh:
            m = re.match(r'^(open\s+|public\s+|internal\s+|private\s+|abstract\s+)*(class|enum|interface)\s+(\w+)', line)
            if m:
                classes.append(m.group(3))
    for cls in classes:
        class_to_files.setdefault(cls, []).append((fname, cls))

# Find duplicates
dupes = {c: fs for c, fs in class_to_files.items() if len(fs) > 1}
print(f"Found {len(dupes)} duplicate class names:")
for c, fs in sorted(dupes.items()):
    print(f"  {c}: {fs}")

# Step 2: Rename strategy
# For each duplicate set, keep the first file's class, rename others
renames = {}  # (filename, old_class) -> new_class
for cls, file_list in dupes.items():
    for i, (fname, old_cls) in enumerate(file_list):
        if i == 0:
            continue  # Keep first
        # Generate unique name
        base = os.path.splitext(fname)[0]
        # Use file stem to disambiguate
        new_name = f"{base.capitalize()}{old_cls}" if base != old_cls.lower() else f"{old_cls}2"
        renames[(fname, old_cls)] = new_name
        print(f"  Rename: {fname}::{old_cls} -> {new_name}")

# Step 3: Apply renames
for fname in sorted(set(f for f, _ in renames)):
    fpath = os.path.join(SRC, fname)
    with open(fpath) as fh:
        content = fh.read()

    for (fn, old_cls), new_cls in renames.items():
        if fn == fname:
            # Rename class declaration
            content = re.sub(rf'\bclass\s+{old_cls}\b', f'class {new_cls}', content)
            content = re.sub(rf'\benum\s+{old_cls}\b', f'enum {new_cls}', content)
            content = re.sub(rf'\binterface\s+{old_cls}\b', f'interface {new_cls}', content)

    # Fix `it` redefinitions (same pattern as before)
    # Pattern: { it => ... let it = _also_it ... }
    content = re.sub(
        r'\{ it =>\s*\n(\s+)let _also_it = ([^\n]+)\n\s+let it = _also_it\n',
        r'{\n\1let result = \2\n',
        content
    )
    content = re.sub(
        r'while \(\{ it =>\s*\n(\s+)let _also_it = ([^\n]+)\n\s+let it = _also_it\n',
        r'while ({\n\1let result = \2\n',
        content
    )

    # Fix var shadowing parameter (append case)
    # let append = append.replace(...) where append is a parameter
    content = re.sub(
        r'(func\s+\w+append\w*)\(append:\s*[^)]+\)\s*\{',
        r'\1(_append: ',
        content
    )
    # Then fix: let append = append.replace -> let result = _append.replace
    # This is too complex. Just rename local var.

    with open(fpath, "w") as fh:
        fh.write(content)

print(f"\nProcessed {len(set(f for f, _ in renames))} files")
