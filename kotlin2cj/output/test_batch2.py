#!/usr/bin/env python3
"""Test batch 2 files individually and as a merge."""
import os, subprocess, tempfile, shutil

SRC = "/home/songy/ksoup/ksoup"
BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

all_files = []
for root, dirs, files in os.walk(SRC):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))
all_files.sort()

batch2 = all_files[25:50]
print(f"Batch 2: {len(batch2)} files (indices 25-49)")

# Test merge of just batch 2
tmpdir = tempfile.mkdtemp()
for fp in batch2:
    rel = os.path.relpath(fp, SRC)
    dest = os.path.join(tmpdir, rel)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copy2(fp, dest)

outdir = tempfile.mkdtemp()
result = subprocess.run([BIN, tmpdir, "-o", outdir], capture_output=True, text=True, timeout=60)
print(f"Merge result: {result.returncode}")
if result.returncode == 0:
    src_out = os.path.join(outdir, "src")
    cj_count = len(os.listdir(src_out)) if os.path.isdir(src_out) else 0
    print(f"  .cj files: {cj_count}")
    print(f"  stderr: {result.stderr.strip()[:200]}")
else:
    print(f"  ERROR: {result.stderr.strip()[:200]}")

# Also test individual files
print("\nIndividual file tests:")
for fp in batch2[:10]:
    r = subprocess.run([BIN, fp], capture_output=True, text=True, timeout=15)
    status = "OK" if r.returncode == 0 else f"FAIL: {r.stderr.strip()[:80]}"
    print(f"  {os.path.basename(fp)}: {status}")

shutil.rmtree(tmpdir, ignore_errors=True)
shutil.rmtree(outdir, ignore_errors=True)
