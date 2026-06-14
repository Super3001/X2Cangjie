#!/usr/bin/env python3
"""Find KMP duplicate classes in ksoup_cj output."""
import os, re

SRC = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

class_to_files = {}
for fname in sorted(os.listdir(SRC)):
    if not fname.endswith(".cj"):
        continue
    fpath = os.path.join(SRC, fname)
    with open(fpath) as fh:
        for line in fh:
            m = re.match(r'^(open\s+|public\s+|internal\s+|private\s+)?(class|enum|interface)\s+(\w+)', line)
            if m:
                cls_name = m.group(3)
                class_to_files.setdefault(cls_name, []).append(fname)
                break

print("=== Duplicate class names ===")
for cls_name, files in sorted(class_to_files.items()):
    if len(files) > 1:
        print(f"  {cls_name}: {files}")

print(f"\n=== File count: {len([f for f in os.listdir(SRC) if f.endswith('.cj')])} ===")
print(f"=== Unique classes: {len(class_to_files)} ===")
