#!/usr/bin/env python3
"""Bisect: find which files cause merge translation to fail."""
import os, sys, subprocess, shutil, tempfile

src_dir = sys.argv[1]
binary = sys.argv[2] if len(sys.argv) > 2 else "./target/release/kotlin2cj"

all_files = []
for root, dirs, files in os.walk(src_dir):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))
all_files.sort()

print(f"Total .kt files: {len(all_files)}")

# Try increasing batch sizes
for batch_size in [10, 25, 50, 75, 90, 100]:
    batch = all_files[:batch_size]
    tmpdir = tempfile.mkdtemp()
    for fpath in batch:
        rel = os.path.relpath(fpath, src_dir)
        dest = os.path.join(tmpdir, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(fpath, dest)

    outdir = tempfile.mkdtemp()
    result = subprocess.run(
        [binary, tmpdir, "-o", outdir],
        capture_output=True, text=True, timeout=60
    )

    status = "OK" if result.returncode == 0 else f"FAIL: {result.stderr.strip()[:150]}"
    print(f"  First {batch_size}: {status}")

    shutil.rmtree(tmpdir, ignore_errors=True)
    shutil.rmtree(outdir, ignore_errors=True)

    if result.returncode != 0:
        # Bisect to find problematic file
        lo, hi = batch_size // 2, batch_size
        # ... simplified: just report the range
        break
