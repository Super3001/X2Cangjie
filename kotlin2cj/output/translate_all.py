#!/usr/bin/env python3
"""Translate each .kt file individually, then create combined cjpm project."""
import os, sys, subprocess, shutil

src_dir = sys.argv[1]
out_dir = sys.argv[2]
binary = sys.argv[3] if len(sys.argv) > 3 else "./target/release/kotlin2cj"

# Step 1: translate each file individually to temp dirs
all_files = []
for root, dirs, files in os.walk(src_dir):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))

print(f"Translating {len(all_files)} files individually...")
ok, fail = 0, []
for fpath in all_files:
    # Use a temp output path
    out_path = fpath.replace(src_dir.rstrip("/"), "/tmp/ksoup_indiv").replace(".kt", ".cj")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    result = subprocess.run(
        [binary, fpath, "-o", out_path],
        capture_output=True, text=True, timeout=30
    )

    if result.returncode == 0:
        ok += 1
        if "SOC:" in result.stderr:
            print(f"  OK {os.path.basename(fpath)} [{result.stderr.strip()}]")
    else:
        fail.append((os.path.basename(fpath), result.stderr.strip()[:150]))
        print(f"  FAIL {os.path.basename(fpath)}: {result.stderr.strip()[:120]}")

print(f"\nTranslated: {ok}/{len(all_files)}")
if fail:
    print(f"Failed ({len(fail)}):")
    for name, err in fail:
        print(f"  {name}: {err}")

# Step 2: copy all successful .cj outputs to a single src/ directory
# and create cjpm.toml
cj_dir = out_dir
os.makedirs(os.path.join(cj_dir, "src"), exist_ok=True)

cj_count = 0
for fpath in all_files:
    cj_path = fpath.replace(src_dir.rstrip("/"), "/tmp/ksoup_indiv").replace(".kt", ".cj")
    if os.path.exists(cj_path):
        basename = os.path.basename(cj_path)
        shutil.copy2(cj_path, os.path.join(cj_dir, "src", basename))
        cj_count += 1

print(f"\nCombined {cj_count} .cj files into {cj_dir}/src/")
