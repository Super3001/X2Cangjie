#!/usr/bin/env python3
"""
Translate target_1f: koin-core commonMain from C:/Codes/kotlin/koin (project mode).

R9 change — first scripted pipeline for 1f
------------------------------------------
1f R1-R8 (2026-07-0x) were translated ad-hoc (no script survived). This script
follows the translate_1g.py project-mode pattern: one-pass tree translation so
project.rs emits a single shared k2cj_stubs.cj and a cjpm.toml carrying
`--error-count-limit all` (metric基线口径). The legacy output/target_1f/ dir is
kept as-is for history; new rounds write to target_1f_r9 (or -o override).

NOTE on metrics: the R8 record "7 errors" predates the 2026-07-09 error-count
口径修正 — compile_r10.log actually ends with "794 errors generated, 8 errors
printed". All 1f measurements from R9 on use "N errors generated" only.

Usage:
    python output/translate_1f.py [-o OUTDIR]
    python output/translate_1f.py --check
    python output/translate_1f.py --validate -o OUTDIR
"""
import argparse
import os
import shutil
import subprocess
import sys

ROOT = r"C:\Codes\X2Cangjie\kotlin2cj"
SRC = r"C:\Codes\kotlin\koin\projects\core\koin-core\src\commonMain\kotlin\org\koin"
BIN = os.path.join(ROOT, "target", "release", "kotlin2cj.exe")
DEFAULT_OUT = os.path.join(ROOT, "output", "target_1f_r9")


def _count_kt(base):
    n = 0
    for _r, _d, files in os.walk(base):
        n += sum(1 for f in files if f.endswith(".kt"))
    return n


def check() -> bool:
    print("== translate_1f --check ==")
    ok = True
    if not os.path.isfile(BIN):
        print(f"  MISSING translator: {BIN} (cargo build --release)")
        ok = False
    else:
        print(f"  translator: {BIN}")
    if not os.path.isdir(SRC):
        print(f"  MISSING source dir: {SRC}")
        ok = False
    else:
        print(f"  source: {SRC}  ({_count_kt(SRC)} .kt)")
    return ok


def validate(out) -> bool:
    print(f"== translate_1f --validate ({out}) ==")
    src_dir = os.path.join(out, "src")
    cj = [f for f in os.listdir(src_dir) if f.endswith(".cj")] if os.path.isdir(src_dir) else []
    toml_ok = os.path.isfile(os.path.join(out, "cjpm.toml"))
    stubs_ok = os.path.isfile(os.path.join(src_dir, "k2cj_stubs.cj"))
    print(f"  .cj files: {len(cj)}, cjpm.toml: {toml_ok}, k2cj_stubs.cj: {stubs_ok}")
    return len(cj) > 0 and toml_ok


def run(out) -> bool:
    print("== translate_1f run (project mode) ==")
    # Back up existing output (file_safety) before overwrite.
    if os.path.isdir(out):
        bak = out + ".bak"
        if os.path.isdir(bak):
            shutil.rmtree(bak)
        shutil.move(out, bak)
        print(f"  backed up existing {out} -> {bak}")
    r = subprocess.run([BIN, SRC, "-o", out], capture_output=True, text=True, timeout=300)
    print(r.stdout.strip()[-800:])
    if r.returncode != 0:
        print(f"  TRANSLATE FAILED (rc={r.returncode})")
        print(r.stderr.strip()[-1200:])
        return False
    print(f"  assembled into {out}")
    return True


def main():
    ap = argparse.ArgumentParser(description="Translate koin-core commonMain (project mode)")
    ap.add_argument("-o", "--out", default=DEFAULT_OUT)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--validate", action="store_true")
    args = ap.parse_args()
    if args.check:
        sys.exit(0 if check() else 1)
    if args.validate:
        sys.exit(0 if validate(args.out) else 1)
    if not check():
        print("Pre-check failed, aborting.")
        sys.exit(1)
    sys.exit(0 if run(args.out) else 1)


if __name__ == "__main__":
    main()
