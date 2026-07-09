#!/usr/bin/env python3
"""
Translate target_1g: full ksoup main module from C:/Codes/kotlin/ksoup (project mode).

R9 change — switched from PER-FILE to PROJECT mode
--------------------------------------------------
The original per-file translation (one `.kt` at a time, then assembled) existed to
bypass an early merge-parser bug. That bug is resolved (R3-R6 parser fixes: expect
class, split_top, object-expr, etc.), so project mode now translates the whole tree
in one pass. Project mode is the correct path here because it emits ALL stdlib stubs
(incl. non-generic typealias like `type ByteArray = Array<Byte>`) into a SINGLE
shared `k2cj_stubs.cj` (see src/project.rs::collect_stubs), instead of injecting them
per-file. Per-file stub injection (src/render.rs) is single-file-mode ONLY; assembling
multiple single-file outputs duplicated those stubs and produced `redefinition of
declaration` errors that blocked the whole package at the decl phase (R6 target_1g_r8
was stuck on 8 such stub redefinitions). The old per-file script is recoverable from
git history if ever needed.

Usage:
    python output/translate_1g.py [-o OUTDIR]
    python output/translate_1g.py --check
    python output/translate_1g.py --validate -o OUTDIR
"""
import argparse
import os
import shutil
import subprocess
import sys

ROOT = r"C:\Codes\X2Cangjie\kotlin2cj"
SRC = r"C:\Codes\kotlin\ksoup\ksoup\src\com\fleeksoft\ksoup"
BIN = os.path.join(ROOT, "target", "release", "kotlin2cj.exe")
DEFAULT_OUT = os.path.join(ROOT, "output", "target_1g_r9")


def _count_kt(base):
    n = 0
    for _r, _d, files in os.walk(base):
        n += sum(1 for f in files if f.endswith(".kt"))
    return n


def check() -> bool:
    print("== translate_1g --check ==")
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
    print(f"== translate_1g --validate ({out}) ==")
    src_dir = os.path.join(out, "src")
    cj = [f for f in os.listdir(src_dir) if f.endswith(".cj")] if os.path.isdir(src_dir) else []
    toml_ok = os.path.isfile(os.path.join(out, "cjpm.toml"))
    stubs_ok = os.path.isfile(os.path.join(src_dir, "k2cj_stubs.cj"))
    print(f"  .cj files: {len(cj)}, cjpm.toml: {toml_ok}, k2cj_stubs.cj: {stubs_ok}")
    return len(cj) > 0 and toml_ok


def run(out) -> bool:
    print("== translate_1g run (project mode) ==")
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
    ap = argparse.ArgumentParser(description="Translate ksoup full module (project mode)")
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
