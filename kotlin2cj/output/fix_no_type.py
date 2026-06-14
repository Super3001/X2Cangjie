#!/usr/bin/env python3
"""Post-process .cj files: add : Any type to let declarations without type or init.
Also fix top-level let declarations that should be inside class (computed properties).
"""
import os, sys, re

SRC = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

for fname in sorted(os.listdir(SRC)):
    if not fname.endswith(".cj"):
        continue
    fpath = os.path.join(SRC, fname)
    with open(fpath) as fh:
        content = fh.read()

    lines = content.split("\n")
    fixed_lines = []
    in_class = False
    class_brace_depth = 0
    top_level_lets = []  # (line_idx, line) for top-level let with type but no init

    for i, line in enumerate(lines):
        # Track class scope
        if re.match(r'^\s*(public\s+|private\s+|internal\s+|protected\s+)?class\s+', line):
            in_class = True
        if in_class and '{' in line:
            class_brace_depth += line.count('{')
        if in_class and '}' in line:
            class_brace_depth -= line.count('}')
            if class_brace_depth <= 0:
                in_class = False
                class_brace_depth = 0

        # Fix: let <name> without : or = → add : Any
        # Match: let <name> (end of line, no : or =)
        stripped = line.strip()
        if re.match(r'^(public\s+|private\s+|internal\s+|protected\s+)?let\s+\w+\s*$', stripped):
            # Has no type and no init
            indent = line[:len(line) - len(line.lstrip())]
            name_match = re.match(r'^(\s*(?:public\s+|private\s+|internal\s+|protected\s+)?let\s+)(\w+)\s*$', line)
            if name_match:
                fixed_lines.append(f"{name_match.group(1)}{name_match.group(2)}: Any")
                continue

        fixed_lines.append(line)

    new_content = "\n".join(fixed_lines)
    if new_content != content:
        with open(fpath, "w") as fh:
            fh.write(new_content)
        print(f"Fixed: {fname}")

print("Post-processing complete")
