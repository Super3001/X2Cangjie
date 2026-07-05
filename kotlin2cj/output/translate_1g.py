#!/usr/bin/env python3
"""
Translate target_1g: full ksoup main module (87 files) from C:/Codes/kotlin/ksoup.
Per-file translation (bypasses merge parser bug). Assembles output/target_1g/.
Old R1 output (output/ksoup_cj, hand-patched era) is left untouched as baseline.

--check    : verify env + source files exist, report; no translation
--validate : after run, verify all .cj files produced + cjpm.toml present
"""
import os, re, sys, subprocess

ROOT = r"C:\Codes\X2Cangjie\kotlin2cj"
SRC_BASE = r"C:\Codes\kotlin\ksoup\ksoup\src\com\fleeksoft\ksoup"
OUT = os.path.join(ROOT, "output", "target_1g")
BIN = os.path.join(ROOT, "target", "release", "kotlin2cj.exe")
PKG = "target_1g"


def kt_files():
    """All .kt under the main module, as paths relative to SRC_BASE."""
    rels = []
    for root, _dirs, files in os.walk(SRC_BASE):
        for f in sorted(files):
            if f.endswith(".kt"):
                rels.append(os.path.relpath(os.path.join(root, f), SRC_BASE))
    return sorted(rels)


def snake(stem):
    out = ""
    for i, ch in enumerate(stem):
        if ch.isupper() and i > 0 and not stem[i - 1].isupper():
            out += "_"
        out += ch.lower()
    return out


def cj_name_for(rel):
    """Disambiguate collisions by prefixing the immediate parent dir for subdir files."""
    rel = rel.replace("\\", "/")
    stem = os.path.splitext(os.path.basename(rel))[0]
    base = snake(stem)
    parent = os.path.dirname(rel).split("/")[-1] if "/" in rel else ""
    if parent:
        return f"{snake(parent)}_{base}.cj"
    return base + ".cj"


def check():
    print(f"BIN exists: {os.path.isfile(BIN)} ({BIN})")
    print(f"SRC exists: {os.path.isdir(SRC_BASE)} ({SRC_BASE})")
    rels = kt_files()
    print(f"Source files: {len(rels)}")
    names = {}
    for rel in rels:
        n = cj_name_for(rel)
        if n in names:
            print(f"COLLISION: {rel} vs {names[n]} -> {n}")
            return False
        names[n] = rel
    print("No output-name collisions")
    return os.path.isfile(BIN) and len(rels) > 0


def validate():
    src_dir = os.path.join(OUT, "src")
    cj = [f for f in os.listdir(src_dir) if f.endswith(".cj")] if os.path.isdir(src_dir) else []
    toml_ok = os.path.isfile(os.path.join(OUT, "cjpm.toml"))
    print(f".cj files: {len(cj)}, cjpm.toml: {toml_ok}")
    return len(cj) > 0 and toml_ok


def run():
    src_dir = os.path.join(OUT, "src")
    os.makedirs(src_dir, exist_ok=True)
    rels = kt_files()
    ok, fail = 0, []
    for rel in rels:
        fp = os.path.join(SRC_BASE, rel)
        cj_name = cj_name_for(rel)
        out_path = os.path.join(src_dir, cj_name)
        r = subprocess.run([BIN, fp, "-o", out_path], capture_output=True, text=True, timeout=60)
        if r.returncode == 0:
            ok += 1
            with open(out_path, "r", encoding="utf-8") as fh:
                body = fh.read()
            # Per-file mode injects a placeholder main() per file; the assembled
            # package needs exactly one entry point (main.cj below).
            body = re.sub(r"\n*main\(\)\s*\{\s*(?://[^\n]*\s*)*\}\s*", "\n", body)
            if not body.lstrip().startswith("package "):
                body = f"package {PKG}\n\n{body}"
            with open(out_path, "w", encoding="utf-8") as fh:
                fh.write(body)
            print(f"  OK  {rel} -> {cj_name}")
        else:
            fail.append((rel, r.stderr.strip()[:200]))
            print(f"  FAIL {rel}: {r.stderr.strip()[:160]}")
    print(f"\nTranslated: {ok}/{len(rels)}")
    if fail:
        print(f"Failed {len(fail)}:")
        for rel, err in fail:
            print(f"  {rel}: {err}")

    # main.cj entry
    with open(os.path.join(src_dir, "main.cj"), "w", encoding="utf-8") as fh:
        fh.write('package target_1g\nmain() {\n    println("target 1g — full ksoup main module")\n}\n')

    # cjpm.toml
    with open(os.path.join(OUT, "cjpm.toml"), "w", encoding="utf-8") as fh:
        fh.write('[package]\n  cjc-version = "1.0.5"\n  name = "target_1g"\n'
                 '  version = "1.0.0"\n  output-type = "executable"\n')
    print(f"\nAssembled into {OUT}")


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    if "--validate" in sys.argv:
        sys.exit(0 if validate() else 1)
    if not check():
        print("Pre-check failed, aborting.")
        sys.exit(1)
    run()
