#!/usr/bin/env python3
import os, re

SRC = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

for fname in os.listdir(SRC):
    if not fname.endswith(".cj"):
        continue
    fpath = os.path.join(SRC, fname)
    with open(fpath) as f:
        lines = f.readlines()
    new_lines = []
    changed = False
    for line in lines:
        # Remove lines like: public func <T, ...>(: ): Unit
        if re.match(r'^\s*(public\s+|static\s+|private\s+)*func\s+<', line) and 'Unit' in line and '(' in line:
            new_lines.append('    // NOTE: inline reified function omitted\n')
            changed = True
        else:
            new_lines.append(line)
    if changed:
        with open(fpath, 'w') as f:
            f.writelines(new_lines)
        print(f"Fixed: {fname}")

print("Done")
