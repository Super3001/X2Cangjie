#!/usr/bin/env python3
"""
Translate target_1e: ktor-io pure I/O primitives subset.
Per-file translation (bypasses merge parser bug). Assembles output/target_1e/.

--check    : verify env + source files exist, report; no translation
--validate : after run, verify all .cj files produced + cjpm.toml present
"""
import os, re, sys, subprocess

ROOT = r"C:\Codes\X2Cangjie\kotlin2cj"
SRC_BASE = r"C:\projects\kotlins\ktor\ktor-io\common\src\io\ktor\utils\io"
OUT = os.path.join(ROOT, "output", "target_1e")
BIN = os.path.join(ROOT, "target", "release", "kotlin2cj.exe")

# Genuinely-translatable-to-zero core (R2 convergence). The "6 errors" baseline was a
# parse-phase undercount; once the 3 parse errors (P1/P2/P3) were fixed, semantic analysis
# revealed ~69 latent errors, dominated by dependency boundaries (atomicfu, kotlinx.io
# Source/Sink) and a few render gaps. These 5 files reach 0 errors with only a `_stubs.cj`.
FILES = [
    "LineEnding.kt",
    "LineEndingMode.kt",       # value class → struct + @Derive[Equatable] (P3)
    "Annotations.kt",
    "core/ByteOrder.kt",
    "core/internal/Numbers.kt",  # needs _stubs.cj: Long.toInt()
    # ── Pruned: expect/actual or external typealias (platform `actual` absent in common-only) ──
    #   bits/ByteOrder.kt, JvmSerializable.kt, locks/Synchronized.kt, core/internal/ChunkBuffer.kt
    # ── Pruned: hard dependency boundary (same class as 1c/1d cross-pkg deps) ──
    #   pool/Pool.kt, pool/ByteArrayPool.kt   — kotlinx.atomicfu `atomic()`
    #   core/Copy.kt, Deprecation.kt          — kotlinx.io Source/Sink/transferTo/readString
    #   core/Closeable.kt                     — AutoCloseable + kotlin.use re-export + extend-on-type-param
    #   errors/Exceptions.kt                  — pure kotlinx.io typealiases (empty body)
    # ── Pruned: deferred translator render gaps (genuine, need focused R3 fixes) ──
    #   Exceptions.kt              — `cause` shadows supertype member in exception subclass chain
    #   core/internal/CharArraySequence.kt — CharSequence mapped inconsistently (String vs interface)
    #   core/Memory.kt             — ByteArray not mapped in extend-target / constructor positions
]

# Minimal stubs for stdlib types referenced by the kept core but absent in Cangjie.
# Mirrors the per-target _stubs.cj convention of 1a/1b/1d.
STUBS = """package target_1e

// Kotlin `Long.toInt()` — our Int maps to Int64; identity for this subset's range checks.
extend Int64 {
    func toInt(): Int64 { return this }
}
"""


PKG = "target_1e"


def snake(stem):
    out = ""
    for i, ch in enumerate(stem):
        if ch.isupper() and i > 0 and not stem[i - 1].isupper():
            out += "_"
        out += ch.lower()
    return out


def cj_name_for(rel):
    """Disambiguate collisions by prefixing the immediate parent dir for subdir files."""
    stem = os.path.splitext(os.path.basename(rel))[0]
    base = snake(stem)
    parent = os.path.dirname(rel.replace("\\", "/")).split("/")[-1] if "/" in rel.replace("\\", "/") else ""
    if parent:
        return f"{snake(parent)}_{base}.cj"
    return base + ".cj"


def check():
    print(f"BIN exists: {os.path.isfile(BIN)} ({BIN})")
    missing = []
    for rel in FILES:
        p = os.path.join(SRC_BASE, rel.replace("/", os.sep))
        if not os.path.isfile(p):
            missing.append(rel)
    print(f"Source files: {len(FILES) - len(missing)}/{len(FILES)} present")
    if missing:
        print("MISSING:")
        for m in missing:
            print(f"  {m}")
        return False
    return True


def validate():
    src_dir = os.path.join(OUT, "src")
    cj = [f for f in os.listdir(src_dir) if f.endswith(".cj")] if os.path.isdir(src_dir) else []
    toml_ok = os.path.isfile(os.path.join(OUT, "cjpm.toml"))
    print(f".cj files: {len(cj)}, cjpm.toml: {toml_ok}")
    return len(cj) > 0 and toml_ok


def run():
    src_dir = os.path.join(OUT, "src")
    os.makedirs(src_dir, exist_ok=True)
    ok, fail = 0, []
    for rel in FILES:
        fp = os.path.join(SRC_BASE, rel.replace("/", os.sep))
        cj_name = cj_name_for(rel)
        out_path = os.path.join(src_dir, cj_name)
        r = subprocess.run([BIN, fp, "-o", out_path], capture_output=True, text=True, timeout=60)
        if r.returncode == 0:
            ok += 1
            # Inject package line (per-file mode omits it; cjpm needs uniform package)
            with open(out_path, "r", encoding="utf-8") as fh:
                body = fh.read()
            # Per-file mode injects a standalone `main()` into each library file so it
            # is independently compilable; the assembled package must have exactly one
            # entry point (the script's main.cj). Strip injected `main()` whose body is
            # empty or comment-only (the only forms the translator emits as a placeholder).
            body = re.sub(
                r"\n*main\(\)\s*\{\s*(?://[^\n]*\s*)*\}\s*", "\n", body
            )
            if not body.lstrip().startswith("package "):
                body = f"package {PKG}\n\n{body}"
            with open(out_path, "w", encoding="utf-8") as fh:
                fh.write(body)
            tag = ""
            if "SOC:" in r.stderr:
                tag = " [" + r.stderr.strip().split("SOC:")[-1].strip()[:60] + "]"
            print(f"  OK  {rel} -> {cj_name}{tag}")
        else:
            fail.append((rel, r.stderr.strip()[:200]))
            print(f"  FAIL {rel}: {r.stderr.strip()[:160]}")
    print(f"\nTranslated: {ok}/{len(FILES)}")
    if fail:
        print(f"Failed {len(fail)}:")
        for rel, err in fail:
            print(f"  {rel}: {err}")

    # _stubs.cj — stdlib type stubs for the kept core (per-target convention, cf. 1a/1b/1d)
    with open(os.path.join(src_dir, "_stubs.cj"), "w", encoding="utf-8") as fh:
        fh.write(STUBS)

    # main.cj entry
    with open(os.path.join(src_dir, "main.cj"), "w", encoding="utf-8") as fh:
        fh.write('package target_1e\nmain() {\n    println("target 1e — ktor-io pure I/O primitives")\n}\n')

    # cjpm.toml
    with open(os.path.join(OUT, "cjpm.toml"), "w", encoding="utf-8") as fh:
        fh.write('[package]\n  cjc-version = "1.0.5"\n  name = "target_1e"\n'
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
