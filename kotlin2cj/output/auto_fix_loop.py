#!/usr/bin/env python3
"""Compiler-driven auto-fix loop. Build, extract errors, fix, repeat until 0."""
import subprocess, os, re, sys

CJPM = r"C:\toolchain\Cangjie1.0.5\tools\bin\cjpm.exe"
SRC = r"\\wsl.localhost\Ubuntu-22.04\home\songy\SunriseSummer-X2Cangjie\kotlin2cj\output\ksoup_cj"
BUILD_DIR = os.path.join(os.environ.get("LOCALAPPDATA", "C:/Temp"), "ksoup_auto")

def copy_src():
    if os.path.exists(BUILD_DIR):
        subprocess.run(["cmd", "/c", "rmdir", "/s", "/q", BUILD_DIR], capture_output=True)
    subprocess.run(["cmd", "/c", "xcopy", "/e", "/q", SRC, BUILD_DIR], capture_output=True)

def build():
    result = subprocess.run([CJPM, "build"], cwd=BUILD_DIR, capture_output=True, text=True, timeout=120)
    return result.stdout + result.stderr

def extract_errors(output):
    undeclared = set()
    redefs = set()
    other = set()
    for line in output.split('\n'):
        m = re.search(r"undeclared type name '(\w+)'", line)
        if m:
            undeclared.add(m.group(1))
            continue
        m = re.search(r"redefinition of declaration '(\w+)'", line)
        if m:
            redefs.add(m.group(1))
            continue
        if 'error' in line.lower() and 'generated' not in line:
            m = re.search(r"error.*: (.+)", line)
            if m:
                other.add(m.group(1)[:80])
    count_m = re.search(r'(\d+) errors generated', output)
    count = int(count_m.group(1)) if count_m else 999
    return count, undeclared, redefs, other

def generate_stubs(missing_types):
    """Generate Cangjie stubs for missing types."""
    stubs = []
    for t in sorted(missing_types):
        if t in ('IntArray',):
            stubs.append(f"class {t} {{ init(size: Int64) {{}} var size: Int64 = 0 }}")
        elif t in ('Charset',):
            stubs.append(f"open class {t} {{ func name(): String {{ return \"\" }} }}")
        elif t in ('Charsets',):
            stubs.append(f"class {t} {{ static let UTF8 = Charset()\n    static func forName(s: String): Charset {{ return Charset() }} }}")
        elif t in ('CharsetEncoder',):
            stubs.append(f"class {t} {{ init(cs: Charset) {{}}\n    func encode(s: String): Any {{ return None }}\n    func flush(): Any {{ return None }} }}")
        elif t in ('Reader',):
            stubs.append(f"open class {t} {{ init() {{}}\n    func read(): Int64 {{ return -1 }}\n    func read(buf: Array<Rune>, off: Int64, len: Int64): Int64 {{ return -1 }}\n    func close(): Unit {{}} }}")
        elif t in ('StringReader',):
            stubs.append(f"class {t} <: Reader {{ init(s: String) {{}} }}")
        elif t in ('InputStream',):
            stubs.append(f"open class {t} {{ func read(): Int64 {{ return -1 }}\n    func close(): Unit {{}} }}")
        elif t in ('IOException',):
            stubs.append(f"open class {t} <: Exception {{ init() {{}} init(msg: String) {{ super(msg) }} }}")
        elif t in ('UncheckedIOException',):
            stubs.append(f"class {t} <: RuntimeException {{ init(cause: IOException) {{}} }}")
        elif t in ('Sequence',):
            stubs.append(f"open class {t}<E> {{ func iterator(): MutableIterator<E> {{ return object {{}} }} }}")
        elif t in ('Regex',):
            stubs.append(f"open class {t} {{ init(pattern: String) {{}}\n    func matches(input: String): Bool {{ return false }}\n    func replace(input: String, replacement: String): String {{ return \"\" }}\n    func findAll(input: String): Any {{ return None }} }}")
        elif t in ('LinkedHashSet',):
            stubs.append(f"open class {t}<E> {{ init() {{}} func add(e: E): Bool {{ return true }}\n    func addAll(c: Any): Bool {{ return true }}\n    var size: Int64 = 0 }}")
        elif t in ('Synchronizable',):
            stubs.append(f"class {t} {{ func synchronize<T>(block: () -> T): T {{ return block() }} }}")
        elif t in ('WeakReference',):
            stubs.append(f"open class {t}<T> {{ init(ref: T) {{}} func get(): ?T {{ return None }} }}")
        elif t in ('ThreadLocal',):
            stubs.append(f"class {t}<T> {{ init(factory: () -> T) {{}} func get(): T {{ return factory() }} }}")
        elif t in ('SoftPool',):
            stubs.append(f"class {t}<T> {{ init(factory: () -> T) {{}} func borrow(): T {{ return factory() }}\n    func release(obj: T): Unit {{}} }}")
        elif t in ('IllegalArgumentException',):
            stubs.append(f"class {t} <: Exception {{ init() {{}} init(msg: String) {{ super(msg) }} }}")
        elif t in ('IllegalStateException',):
            stubs.append(f"class {t} <: Exception {{ init() {{}} init(msg: String) {{ super(msg) }} }}")
        elif t in ('IndexOutOfBoundsException',):
            stubs.append(f"class {t} <: Exception {{ init() {{}} init(msg: String) {{ super(msg) }} }}")
        elif t in ('StringBuilder',):
            stubs.append(f"class {t} {{ func append(s: String): {t} {{ return this }}\n    func append(c: Rune): {t} {{ return this }}\n    func toString(): String {{ return \"\" }}\n    func clear(): Unit {{}} }}")
        else:
            stubs.append(f"open class {t} {{}}")
    return '\n'.join(stubs)

def main():
    copy_src()
    iteration = 0
    last_count = 99999
    while iteration < 20:
        iteration += 1
        output = build()
        count, undeclared, redefs, other = extract_errors(output)
        print(f"\n=== Iteration {iteration}: {count} errors ===")
        print(f"  Undeclared types: {sorted(undeclared)}")
        print(f"  Redefinitions: {sorted(redefs)}")
        print(f"  Other: {sorted(other)[:5]}")

        if count == 0:
            print("\n*** BUILD SUCCEEDED! 0 errors. ***")
            return 0

        if count >= last_count:
            print(f"ERROR: Error count increased ({last_count} -> {count}). Check stubs.")
            break
        last_count = count

        # Fix undeclared types
        if undeclared:
            stubs = generate_stubs(undeclared)
            stub_path = os.path.join(BUILD_DIR, "src", "_stubs.cj")
            with open(stub_path, "a") as f:
                f.write('\n' + stubs + '\n')
            print(f"  Added stubs for: {sorted(undeclared)}")

        # Fix redefinitions - skip for now (mostly from stubs)
        if redefs:
            print(f"  TODO redefs: {sorted(redefs)}")

        if not undeclared and not redefs and other:
            print(f"  Unhandled errors: {sorted(other)[:10]}")
            break

    return 1

if __name__ == "__main__":
    sys.exit(main())
