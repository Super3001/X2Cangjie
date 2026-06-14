#!/usr/bin/env python3
"""Find which .kt file contains line 184 of the merged source."""
import os
import sys

src_dir = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/ksoup/ksoup/src"

# Collect all .kt files in order (same order as project.rs would process)
# project.rs: non_main first, then main. For simplicity, sort all.
all_files = []
for root, dirs, files in os.walk(src_dir):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))

print(f"Total .kt files: {len(all_files)}")

# Simulate the merging (non_main first, then main)
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

# Merge and find line 184
cursor = 0
for fpath, src in non_main + main_files:
    start = cursor
    src_lines = src.count("\n") + 1
    end = cursor + src_lines + 1  # +1 for the newline added in merge
    if start < 184 and end >= 184:
        rel_line = 184 - cursor
        print(f"\nLine 184 of merged source is in: {fpath}")
        print(f"  Merged range: [{start}, {end})")
        print(f"  Relative line in file: {rel_line}")
        file_lines = src.split("\n")
        start_idx = max(0, rel_line - 5)
        end_idx = min(len(file_lines), rel_line + 3)
        print(f"  Context (lines {start_idx+1}-{end_idx+1}):")
        for i in range(start_idx, end_idx):
            marker = ">>>" if i == rel_line - 1 else "   "
            print(f"  {marker} {i+1}: {file_lines[i]}")
        break
    cursor = end

print(f"\nFinal cursor: {cursor}")
