#!/usr/bin/env python3
"""Translate each .kt file individually and combine outputs."""
import os, sys, subprocess

src_dir = sys.argv[1]
out_dir = sys.argv[2]
binary = sys.argv[3] if len(sys.argv) > 3 else "./target/release/kotlin2cj"

os.makedirs(os.path.join(out_dir, "src"), exist_ok=True)

all_files = []
for root, dirs, files in os.walk(src_dir):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))

success = 0
failed = []
for fpath in all_files:
    # Determine output filename (same as kt_to_cj_filename logic)
    stem = os.path.splitext(os.path.basename(fpath))[0]
    cj_name = ""
    for i, ch in enumerate(stem):
        if ch.isupper() and i > 0:
            cj_name += "_"
        cj_name += ch.lower()
    cj_name += ".cj"

    out_path = os.path.join(out_dir, "src", cj_name)

    result = subprocess.run(
        [binary, fpath, "-o", out_path],
        capture_output=True, text=True, timeout=30
    )

    if result.returncode == 0:
        success += 1
        if "SOC:" in result.stderr:
            print(f"OK {os.path.basename(fpath)} — {result.stderr.strip()}")
    else:
        failed.append((fpath, result.stderr.strip()[:200]))
        print(f"FAIL {os.path.basename(fpath)}: {result.stderr.strip()[:200]}")

print(f"\nTranslated: {success}/{len(all_files)}")
if failed:
    print(f"Failed: {len(failed)}")
    for f, err in failed[:5]:
        print(f"  {os.path.basename(f)}: {err}")
