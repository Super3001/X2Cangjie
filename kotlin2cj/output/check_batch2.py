#!/usr/bin/env python3
import os, tempfile, shutil, subprocess

SRC = "/home/songy/ksoup/ksoup"
BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

all_files = []
for root, dirs, files in os.walk(SRC):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))
all_files.sort()
batch2 = all_files[25:50]

tmpdir = tempfile.mkdtemp()
for fp in batch2:
    rel = os.path.relpath(fp, SRC)
    dest = os.path.join(tmpdir, rel)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copy2(fp, dest)

outdir = tempfile.mkdtemp()
result = subprocess.run([BIN, tmpdir, "-o", outdir], capture_output=True, text=True, timeout=60)

src_out = os.path.join(outdir, "src")
if os.path.isdir(src_out):
    cj_files = sorted(os.listdir(src_out))
    print("Produced {} .cj files:".format(len(cj_files)))
    for f in cj_files:
        fpath = os.path.join(src_out, f)
        size = os.path.getsize(fpath)
        with open(fpath) as fh:
            content = fh.read()
        lines = content.count("\n")
        has_class = "class " in content or "interface " in content or "enum " in content
        print("  {}: {}B, {} lines, has_decl={}".format(f, size, lines, has_class))
        # Print first 100 chars
        print("    First: {}".format(content[:100].replace("\n", "\\n")))

shutil.rmtree(tmpdir, ignore_errors=True)
shutil.rmtree(outdir, ignore_errors=True)
