#!/usr/bin/env python3
"""Check for unbalanced block comments in Kotlin files."""
import os, sys

src_dir = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/ksoup/ksoup/src"
for root, dirs, files in os.walk(src_dir):
    for f in files:
        if f.endswith(".kt"):
            path = os.path.join(root, f)
            with open(path) as fh:
                content = fh.read()
            open_block = content.count("/*")
            close_block = content.count("*/")
            if open_block != close_block:
                print(f"UNBALANCED: {path} (/* {open_block}, */ {close_block})")
print("Done")
