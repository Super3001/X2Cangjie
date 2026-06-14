#!/usr/bin/env python3
"""
Batch-translate ksoup: split 100 .kt files into batches of 25,
translate each batch (avoiding merge parser bug at >25 files),
then combine all .cj outputs into one cjpm project.
"""
import os, sys, subprocess, shutil, tempfile

SRC_DIR = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/ksoup/ksoup"
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj"
BINARY = sys.argv[3] if len(sys.argv) > 3 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
BATCH_SIZE = 25

# Collect all .kt files
all_files = []
for root, dirs, files in os.walk(SRC_DIR):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))
all_files.sort()

print(f"Total .kt files: {len(all_files)}")

# Split into batches
batches = [all_files[i:i+BATCH_SIZE] for i in range(0, len(all_files), BATCH_SIZE)]
print(f"Batches: {len(batches)} (max {BATCH_SIZE} files each)")

# Translate each batch
all_cj_files = {}  # relpath -> cj_content
total_ok = 0
total_fail = 0

for bi, batch in enumerate(batches):
    # Create temp dir with batch files preserving dir structure
    tmpdir = tempfile.mkdtemp()
    for fpath in batch:
        rel = os.path.relpath(fpath, SRC_DIR)
        dest = os.path.join(tmpdir, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(fpath, dest)

    outdir = tempfile.mkdtemp()
    result = subprocess.run(
        [BINARY, tmpdir, "-o", outdir],
        capture_output=True, text=True, timeout=120
    )

    if result.returncode == 0:
        # Collect .cj files from this batch
        src_dir = os.path.join(outdir, "src")
        if os.path.isdir(src_dir):
            for f in os.listdir(src_dir):
                if f.endswith(".cj"):
                    fpath = os.path.join(src_dir, f)
                    with open(fpath, "r", encoding="utf-8") as fh:
                        all_cj_files[f] = fh.read()
        ok_count = len(os.listdir(src_dir)) if os.path.isdir(src_dir) else 0
        total_ok += ok_count
        stderr_info = result.stderr.strip()
        if "SOC:" in stderr_info:
            print(f"  Batch {bi+1}: {ok_count} files [{stderr_info}]")
        else:
            print(f"  Batch {bi+1}: {ok_count} files")
    else:
        total_fail += len(batch)
        print(f"  Batch {bi+1}: FAILED - {result.stderr.strip()[:120]}")

    shutil.rmtree(tmpdir, ignore_errors=True)
    shutil.rmtree(outdir, ignore_errors=True)

# Combine all .cj outputs
os.makedirs(os.path.join(OUT_DIR, "src"), exist_ok=True)
for name, content in all_cj_files.items():
    with open(os.path.join(OUT_DIR, "src", name), "w", encoding="utf-8") as fh:
        fh.write(content)

# Count collisions from SOC logs
total_cj = len(all_cj_files)
print(f"\n{'='*50}")
print(f"Combined: {total_cj} .cj files into {OUT_DIR}/src/")
print(f"Total successful: {total_ok}, failed: {total_fail}")
