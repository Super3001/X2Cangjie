#!/usr/bin/env python3
import os, sys

src_dir = sys.argv[1]
target = int(sys.argv[2])

all_files = []
for root, dirs, files in os.walk(src_dir):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))
all_files.sort()

non_main = []; main_files = []
for fpath in all_files:
    with open(fpath, "r", encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    has_main = any(l.strip().startswith("fun main(") or l.strip() in ("fun main() {",) for l in src.splitlines())
    if has_main: main_files.append((fpath, src))
    else: non_main.append((fpath, src))

cursor = 0
for fpath, src in non_main + main_files:
    start = cursor
    lines = src.count("\n") + 1
    end = cursor + lines + 1
    if start <= target < end:
        rel = target - start
        flines = src.split("\n")
        print(f"File: {fpath}")
        print(f"Range: [{start}, {end})")
        for i in range(max(0,rel-3), min(len(flines), rel+2)):
            m = ">>>" if i == rel else "   "
            print(f"{m} {start+i+1}: {flines[i]}")
        break
    cursor = end
print(f"End cursor: {cursor}")
