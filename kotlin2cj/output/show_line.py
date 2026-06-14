#!/usr/bin/env python3
"""Print line N of the merged source, exactly as project.rs builds it."""
import os
import sys

src_dir = sys.argv[1]
target_line = int(sys.argv[2])

all_files = []
for root, dirs, files in os.walk(src_dir):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))
all_files.sort()

non_main = []
main_files = []
for fpath in all_files:
    with open(fpath, "r", encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    has_main = any(
        line.strip().startswith("fun main(") or line.strip() == "fun main() {" or line.strip().startswith("fun main()")
        for line in src.splitlines()
    )
    if has_main:
        main_files.append((fpath, src))
    else:
        non_main.append((fpath, src))

merged = ""
for fpath, src in non_main + main_files:
    merged += src + "\n"

lines = merged.split("\n")
# Print context around target line
for i in range(max(0, target_line - 10), min(len(lines), target_line + 5)):
    marker = ">>>" if i + 1 == target_line else "   "
    print(f"{marker} {i+1}: {lines[i]}")
