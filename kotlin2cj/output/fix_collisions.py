#!/usr/bin/env python3
"""Post-process .cj files: resolve var-func name collisions.
Renames backing fields to _<name> when they conflict with getter/setter functions.
Also renames top-level field references inside the class.
"""
import os, sys, re

SRC = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

def fix_file(fpath):
    with open(fpath) as fh:
        content = fh.read()

    lines = content.split("\n")

    # Parse classes and their members
    classes = []
    current_class = None
    brace_depth = 0
    class_start = None

    for i, line in enumerate(lines):
        # Track class start
        m = re.match(r'^(\s*)(public\s+|private\s+|internal\s+|protected\s+)?class\s+(\w+)', line)
        if m and (brace_depth == 0 or current_class is None):
            indent = len(m.group(1))
            current_class = {
                'name': m.group(3),
                'start': i,
                'indent': indent,
                'fields': {},  # name -> line_idx
                'funcs': set(),  # set of func names
                'end': None
            }
            class_start = i

        if current_class is not None:
            # Track braces from class start
            for ch in line:
                if ch == '{':
                    brace_depth += 1
                elif ch == '}':
                    brace_depth -= 1
                    if brace_depth == 0:
                        current_class['end'] = i
                        classes.append(current_class)
                        current_class = None
                        class_start = None

            # Inside class: find fields and funcs
            if current_class is not None and brace_depth == 1:
                # Field: let/var name: Type or let/var name =
                fm = re.match(r'^(\s+)(var|let)\s+(_?\w+)(\s*[=:].*)?$', line)
                if fm:
                    field_name = fm.group(3)
                    if not field_name.startswith('_'):  # Skip already-renamed
                        current_class['fields'][field_name] = i

                # Func: func name(
                fnm = re.match(r'^(\s+)(public\s+|private\s+|internal\s+|protected\s+|override\s+)*func\s+(\w+)\s*\(', line)
                if fnm:
                    func_name = fnm.group(3)
                    current_class['funcs'].add(func_name)

    if not classes:
        return False

    # Find collisions
    renames = {}  # old_name -> new_name
    line_renames = {}  # line_idx -> [(old, new)]

    for cls in classes:
        for field_name, line_idx in cls['fields'].items():
            if field_name in cls['funcs']:
                new_name = f"_{field_name}"
                renames[field_name] = new_name
                line_renames[line_idx] = (field_name, new_name)

    if not renames:
        return False

    # Apply renames (within class scope)
    result_lines = []
    in_class_rename = None
    class_brace = 0

    for i, line in enumerate(lines):
        # Track class scope for contextual renaming
        m = re.match(r'^(\s*)(public\s+|private\s+|internal\s+|protected\s+)?class\s+', line)
        if m:
            in_class_rename = True
        if in_class_rename:
            for ch in line:
                if ch == '{': class_brace += 1
                elif ch == '}':
                    class_brace -= 1
                    if class_brace == 0:
                        in_class_rename = False

        if i in line_renames:
            old, new = line_renames[i]
            # Rename the field declaration
            line = re.sub(rf'\b{old}\b', new, line, count=1)
            result_lines.append(line)
            continue

        # Inside class: rename field references
        # Pattern: this.field or field = or = field or (field) or field.
        if in_class_rename and class_brace == 1:
            for old, new in renames.items():
                # Replace this.old -> this.new
                line = re.sub(rf'\bthis\.{old}\b', f'this.{new}', line)

        result_lines.append(line)

    # Also rename inside function bodies (getters that return the field)
    # Pattern: func old() { return old } -> func old() { return _old }
    for old, new in renames.items():
        for i, line in enumerate(result_lines):
            # Fix getter body: return old -> return _old
            if f'func {old}(' in line:
                # Find the matching return statement
                for j in range(i, min(i + 5, len(result_lines))):
                    if f'return {old}' in result_lines[j]:
                        result_lines[j] = result_lines[j].replace(f'return {old}', f'return {new}')
                    if f'return this.{old}' in result_lines[j]:
                        result_lines[j] = result_lines[j].replace(f'return this.{old}', f'return this.{new}')

            # Fix setter body: this.old = old -> this._old = old
            if f'func {old}(' in line:
                for j in range(i, min(i + 5, len(result_lines))):
                    if f'this.{old}' in result_lines[j]:
                        result_lines[j] = result_lines[j].replace(f'this.{old}', f'this.{new}')

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
