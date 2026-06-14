#!/usr/bin/env python3
"""Print the merge order of .kt files with line ranges, to verify merged line numbers."""
import os
import sys

src_dir = sys.argv[1]

all_files = []
for root, dirs, files in os.walk(src_dir):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))

# Sort paths alphabetically (same as scan_kt_files which uses files.sort())
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

cursor = 0
for fpath, src in non_main + main_files:
    start = cursor
    src_lines = src.count("\n") + 1
    end = cursor + src_lines + 1  # +1 for merged newline
    print(f"[{start:>5}, {end:>5}) {fpath}")
    cursor = end

print(f"\nTotal merged lines: ~{cursor}")
