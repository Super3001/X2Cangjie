#!/usr/bin/env python3
"""Translate each .kt file individually. Bypasses merge parser issues entirely."""
import os, sys, subprocess, shutil

SRC = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/ksoup/ksoup"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj"
BIN = sys.argv[3] if len(sys.argv) > 3 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

all_files = []
for root, dirs, files in os.walk(SRC):
    for f in sorted(files):
        if f.endswith(".kt"):
            all_files.append(os.path.join(root, f))

print("Translating {} files individually...".format(len(all_files)))

os.makedirs(os.path.join(OUT, "src"), exist_ok=True)

ok = 0
fail = []
collisions = []

for fp in all_files:
    stem = os.path.splitext(os.path.basename(fp))[0]
    # Convert CamelCase to snake_case for .cj filename
    cj_name = ""
    for i, ch in enumerate(stem):
        if ch.isupper() and i > 0:
            cj_name += "_"
        cj_name += ch.lower()
    cj_name += ".cj"

    out_path = os.path.join(OUT, "src", cj_name)

    result = subprocess.run(
        [BIN, fp, "-o", out_path],
        capture_output=True, text=True, timeout=30
    )

    if result.returncode == 0:
        ok += 1
        if "SOC:" in result.stderr:
            collisions.append(result.stderr.strip())
    else:
        fail.append((os.path.basename(fp), result.stderr.strip()[:150]))

print("Translated: {}/{}".format(ok, len(all_files)))
if collisions:
    print("Collision resolutions:")
    for c in collisions:
        print("  {}".format(c))
if fail:
    print("Failed ({}):".format(len(fail)))
    for name, err in fail:
        print("  {}: {}".format(name, err))

# Generate cjpm.toml
cjpm_content = """[package]
cjc-version = "1.0.5"
name = "ksoup_cj"
version = "1.0.0"
output-type = "static"
"""
with open(os.path.join(OUT, "cjpm.toml"), "w") as f:
    f.write(cjpm_content)

print("\nOutput: {}/src/ ({} .cj files)".format(OUT, ok))
