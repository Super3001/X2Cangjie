#!/usr/bin/env python3
import os, sys

d = sys.argv[1]
for f in os.listdir(d):
    if f.endswith(".cj"):
        p = os.path.join(d, f)
        with open(p) as fh:
            c = fh.read()
        if not c.startswith("package "):
            with open(p, "w") as fh:
                fh.write("package ksoup_cj\n\n" + c)
print("Done")
