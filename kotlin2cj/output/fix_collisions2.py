#!/usr/bin/env python3
"""Post-process .cj files: resolve var-func name collisions.
Simpler approach: detect var/func pairs with same name, rename fields to _<name>.
"""
import os, sys, re

SRC = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

def fix_file(fpath):
    with open(fpath) as fh:
        content = fh.read()

    lines = content.split("\n")

    # Step 1: Find all field names and func names
    fields = {}  # line_idx -> field_name
    funcs = {}   # line_idx -> func_name

    for i, line in enumerate(lines):
        # Field declaration: let/var name (with type annotation or initializer)
        fm = re.match(r'^\s+(var|let)\s+(_?\w+)\b', line)
        if fm:
            name = fm.group(2)
            if not name.startswith('_'):  # Skip already-renamed
                fields[i] = name

        # Function declaration: func name(
        fnm = re.match(r'^\s+(public\s+|private\s+|internal\s+|protected\s+|override\s+)*func\s+(\w+)\s*\(', line)
        if fnm:
            funcs[i] = fnm.group(2)

    # Step 2: Find collisions (same name in same class context)
    # Group by approximate class location
    all_field_names = set(fields.values())
    all_func_names = set(funcs.values())
    collisions = all_field_names & all_func_names

    if not collisions:
        return False

    # Step 3: Rename fields to _<name>
    renames = {name: f"_{name}" for name in collisions}

    result_lines = []
    for i, line in enumerate(lines):
        if i in fields and fields[i] in renames:
            old = fields[i]
            new = renames[old]
            # Rename the field declaration
            line = re.sub(rf'\b(var|let)\s+{old}\b', rf'\1 {new}', line, count=1)
            result_lines.append(line)
            continue

        # In method bodies: rename this.field -> this._field
        for old, new in renames.items():
            line = re.sub(rf'\bthis\.{old}\b', f'this.{new}', line)

        result_lines.append(line)

    # Step 4: Fix getter/setter bodies
    for old, new in renames.items():
        for i, line in enumerate(result_lines):
            # Getter: func old() { return old }
            if re.match(rf'^\s+.*func\s+{old}\s*\(', line):
                # Look ahead for return old
                for j in range(i, min(i + 8, len(result_lines))):
                    if re.search(rf'\breturn\s+{old}\b', result_lines[j]):
                        result_lines[j] = re.sub(rf'\breturn\s+{old}\b', f'return {new}', result_lines[j])
                    if re.search(rf'\breturn\s+this\.{old}\b', result_lines[j]):
                        result_lines[j] = re.sub(rf'\breturn\s+this\.{old}\b', f'return this.{new}', result_lines[j])

            # Setter: func old(old: Type) { this.old = old }
            if re.match(rf'^\s+.*func\s+{old}\s*\(.*{old}\s*:', line):
                for j in range(i, min(i + 8, len(result_lines))):
                    if f'this.{old} =' in result_lines[j]:
                        result_lines[j] = result_lines[j].replace(f'this.{old} =', f'this.{new} =')

    new_content = "\n".join(result_lines)
    if new_content != content:
        with open(fpath, "w") as fh:
            fh.write(new_content)
        return True
    return False

if __name__ == "__main__":
    fixed = []
    for fname in sorted(os.listdir(SRC)):
        if not fname.endswith(".cj"):
            continue
        fpath = os.path.join(SRC, fname)
        if fix_file(fpath):
            fixed.append(fname)

    print(f"Fixed {len(fixed)} files:")
    for f in fixed:
        print(f"  {f}")
