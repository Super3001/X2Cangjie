#!/usr/bin/env python3
"""Comprehensive post-processing for ksoup .cj files. Single pass, correct order."""
import os, re

SRC = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

# === PHASE 1: Remove KMP duplicate files ===
KMP_DUPES = [
    'platform.android.cj', 'platform.android_native.cj',
    'platform.apple.cj', 'platform.js.cj', 'platform.jvm.cj',
    'platform.linux.cj', 'platform.mingw.cj', 'platform.wasm_js.cj',
    'weak_reference.js.cj', 'weak_reference.native.cj', 'weak_reference.wasm.cj',
]
for fn in KMP_DUPES:
    fp = os.path.join(SRC, fn)
    if os.path.exists(fp):
        os.remove(fp)
        print(f"Removed KMP dup: {fn}")

# === PHASE 2: Fix each .cj file ===
for fname in sorted(os.listdir(SRC)):
    if not fname.endswith(".cj"):
        continue
    fpath = os.path.join(SRC, fname)
    with open(fpath) as f:
        content = f.read()
    original = content

    # -- 2a: Remove corrupted reified generic function lines --
    content = re.sub(
        r'^\s*(public\s+|static\s+|private\s+|override\s+)*func\s+<[^>]*>\([^)]*\):\s*\w+\s*$',
        '    // NOTE: inline reified function omitted — not supported by translator',
        content, flags=re.MULTILINE
    )

    # -- 2b: Fix extend Array<Rune> inside class body --
    # Remove the extend block, replace binarySearch calls with indexOf
    if 'extend Array<Rune> {' in content and 'class ' in content:
        content = re.sub(
            r'    extend Array<Rune> \{\n        func binarySearch\(c: Rune\): Int64 \{\n            return this\.indexOf\(c\)\n        \}\n    \}\n',
            '',
            content
        )
        content = content.replace('chars.binarySearch(c)', 'chars.indexOf(c)')

    # -- 2c: Fix var-func name collisions --
    # Find let/var fields with same name as func in same file
    fields = {}  # line -> name
    funcs = set()
    for i, line in enumerate(content.split('\n')):
        fm = re.match(r'^\s+(var|let)\s+(_?\w+)\b', line)
        if fm:
            name = fm.group(2)
            if not name.startswith('_'):
                fields[i] = name
        fnm = re.match(r'^\s+(?:public\s+|private\s+|internal\s+|protected\s+|override\s+)*func\s+(\w+)\s*\(', line)
        if fnm:
            funcs.add(fnm.group(1))

    collisions = {n for n in fields.values() if n in funcs}
    if collisions:
        lines = content.split('\n')
        renames = {n: f"_{n}" for n in collisions}
        for i, line in enumerate(lines):
            if i in fields and fields[i] in renames:
                old = fields[i]
                new = renames[old]
                lines[i] = re.sub(rf'\b(var|let)\s+{old}\b', rf'\1 {new}', lines[i], count=1)
            # Rename this.field -> this._field for colliding names
            for old, new in renames.items():
                lines[i] = re.sub(rf'\bthis\.{old}\b', f'this.{new}', lines[i])
        # Fix getter/setter bodies: return old -> return _old
        for old, new in renames.items():
            for i, line in enumerate(lines):
                if re.match(rf'^\s+.*func\s+{old}\s*\(', line):
                    # Look forward for return old
                    for j in range(i, min(i+5, len(lines))):
                        if rf'return {old}' in lines[j]:
                            lines[j] = lines[j].replace(f'return {old}', f'return {new}')
                        if rf'return this.{old}' in lines[j]:
                            lines[j] = lines[j].replace(f'return this.{old}', f'return this.{new}')
        content = '\n'.join(lines)

    # -- 2d: Fix evaluator.cj inner class name collisions --
    if fname == 'evaluator.cj':
        content = content.replace('class Tag <: Evaluator', 'class EvalTag <: Evaluator')
        content = content.replace('class Attribute <: Evaluator', 'class EvalAttribute <: Evaluator')

    # -- 2e: Fix missing types on let declarations --
    for pat, replacement in [
        ('    let reader\n', '    let reader: Any\n'),
        ('    let empty\n', '    let empty: Any\n'),
        ('    let codeDelims\n', '    let codeDelims: Any\n'),
        ('    let LocalEncoder\n', '    let LocalEncoder: Any\n'),
        ('    let startPending\n', '    let startPending: Any\n'),
        ('    let endPending\n', '    let endPending: Any\n'),
        ('    let weekRefValue\n', '    let weekRefValue: Any\n'),
    ]:
        if pat in content:
            content = content.replace(pat, replacement)

    # -- 2f: Fix public enum constructor --
    if '| ascii | utf | fallback | public' in content:
        content = content.replace('| ascii | utf | fallback | public', '| ascii | utf | fallback | `public`')
        content = content.replace('case public =>', 'case `public` =>')

    # -- 2g: Fix attributes.keys() = ... (can't assign to function call) --
    if 'attributes.keys() = keys.copyOf' in content:
        content = content.replace('attributes.keys() = keys.copyOf', 'attributes.keys = keys.copyOf')

    # -- 2h: Fix getOrPut pattern in tag_set.cj (complex LHS) --
    if '({ => if (tags.contains(tag.namespace()))' in content:
        content = content.replace(
            '        ({ => if (tags.contains(tag.namespace())) { tags[tag.namespace()] } else { let _v = ({ => HashMap() })(); tags[tag.namespace()] = _v; _v } })()[tag.tagName] = tag',
            '        let ns = tag.namespace()\n        if (!tags.contains(ns)) {\n            tags[ns] = HashMap()\n        }\n        tags[ns][tag.tagName] = tag'
        )

    # -- 2i: Fix token.cj append shadowing (let append = append.replace) --
    if fname == 'token.cj':
        content = content.replace(
            '    public open func appendTagName(append: String) {\n        let append = append.replace',
            '    public open func appendTagName(append: String) {\n        let _result = append.replace'
        )
        content = content.replace(
            '        tagName.append(append)\n        normalName = ParseSettings.normalName(tagName.value())\n    }\n    public open func appendTagName(append: Rune)',
            '        tagName.append(_result)\n        normalName = ParseSettings.normalName(tagName.value())\n    }\n    public open func appendTagName(append: Rune)'
        )
        content = content.replace(
            '    public open func appendAttributeName(append: String, startPos: Int64, endPos: Int64) {\n        let append = append.replace',
            '    public open func appendAttributeName(append: String, startPos: Int64, endPos: Int64) {\n        let _result2 = append.replace'
        )
        content = content.replace(
            '        attrName.append(append)\n        attrNamePos(startPos, endPos)',
            '        attrName.append(_result2)\n        attrNamePos(startPos, endPos)'
        )

    # -- 2j: Fix identity_hash_map.cj structure --
    if fname == 'identity_hash_map.cj':
        content = """package ksoup_cj

import std.collection.*

class IdentityHashMap<K, V> <: MutableMap {
    let delegate: HashMap<IdentityWrapper<K>, V> = HashMap<IdentityWrapper<K>, V>()
    let size: Int64
    public override func containsKey(key: K): Bool {
        return delegate.contains(IdentityWrapper(key))
    }
    public override func containsValue(value: V): Bool {
        return delegate.containsValue(value)
    }
    public override func get(key: K): ?V {
        return delegate[IdentityWrapper(key)]
    }
    public override func isEmpty(): Bool {
        return delegate.isEmpty()
    }
    let entries: HashSet<MutableMap.MutableEntry<K, V>>
    public override func clear() {
        delegate.clear()
    }
    public override func put(key: K, value: V): ?V {
        return delegate.put(IdentityWrapper(key), value)
    }
    public override func putAll(from: HashMap<K, V>) {
        for (__tuple in from) {
            let (k, v) = __tuple
            this[k] = v
        }
    }
    public override func remove(key: K): ?V {
        return delegate.remove(IdentityWrapper(key))
    }
}

class IdentityWrapper<T> {
    let value: T
    init(value: T) {
        this.value = value
    }
    public override func hashCode(): Int64 {
        return value.hashCode()
    }
    public override func equals(other: ?Object): Bool {
        return (other is IdentityWrapper<Object>) && (other.getOrThrow().value == value)
    }
}

class IdentityEntry<K, V> <: MutableMap.MutableEntry {
    let original: MutableMap.MutableEntry<IdentityWrapper<K>, V>
    init(original: MutableMap.MutableEntry<IdentityWrapper<K>, V>) {
        this.original = original
    }
    let key: K
    let value: V
    public override func setValue(newValue: V): V {
        return original.setValue(newValue)
    }
}
"""

    # -- 2k: Fix source_reader.cj optional params in interface --
    if fname == 'source_reader.cj' and '!: Int64 = 0' in content:
        content = content.replace(
            'func read(bytes: ByteArray, offset!: Int64 = 0, length!: Int64 = bytes.size): Int64',
            'func read(bytes: ByteArray, offset: Int64, length: Int64): Int64'
        )

    # -- 2k1: Replace MutableMap.MutableEntry -> MutableEntry (flat namespace) --
    while 'MutableMap.MutableEntry' in content:
        content = content.replace('MutableMap.MutableEntry', 'MutableEntry')

    # -- 2k2: Fix token.cj inner class name collisions --
    if fname == 'token.cj':
        content = content.replace('abstract class Tag <: Token', 'abstract class TokenTag <: Token')
        content = content.replace('class Comment <: Token', 'class TokenComment <: Token')
        content = content.replace('open class Character <: Token', 'open class TokenCharacter <: Token')
        content = content.replace('asComment(): Comment', 'asComment(): TokenComment')
        content = content.replace('asCharacter(): Character', 'asCharacter(): TokenCharacter')
        content = content.replace('(this as Comment)', '(this as TokenComment)')
        content = content.replace('(this as Character)', '(this as TokenCharacter)')

    # -- 2l: Fix xml_tree_builder.cj open func optional params --
    if fname == 'xml_tree_builder.cj':
        content = content.replace(
            'public open func parse(input: Reader, baseUri!: ?String = None): Document',
            'public open func parse(input: Reader, baseUri: ?String): Document'
        )
        content = content.replace(
            'public open func parse(input: String, baseUri!: ?String = None): Document',
            'public open func parse(input: String, baseUri: ?String): Document'
        )

    # -- 2l2: Fix element.cj open func optional params --
    if fname == 'element.cj':
        content = content.replace(
            'public open func tagName(tagName: String, namespace!: String = _tag.namespace()): Element',
            'public open func tagName(tagName: String, namespace: String): Element'
        )

    # -- 2l3: Fix elements.cj param ordering (named before unnamed) --
    if fname == 'elements.cj':
        content = content.replace(
            'func siblings(query!: ?String = None, next: Bool, all: Bool): Elements',
            'func siblings(query: ?String, next: Bool, all: Bool): Elements'
        )

    # -- 2m: Fix html_tree_builder.cj open func optional params --
    if fname == 'html_tree_builder.cj':
        content = content.replace(
            'public open func inScope(targetName: String, extras!: ?Array<String> = None): Bool',
            'public open func inScope(targetName: String, extras: ?Array<String>): Bool'
        )
        content = content.replace(
            'public open func generateImpliedEndTags(thorough!: Bool = false)',
            'public open func generateImpliedEndTags(thorough: Bool)'
        )

    # -- 2n: Fix `let it = _also_it` shadowing (rename to _it) --
    if 'let it = _also_it' in content:
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if 'let it = _also_it' in line:
                # Rename to avoid shadowing lambda 'it' parameter
                lines[i] = line.replace('let it = _also_it', 'let _it = _also_it')
                # Replace 'it.' and 'it)' references below until blank/close
                for j in range(i + 1, min(i + 10, len(lines))):
                    if lines[j].strip() == '' or lines[j].strip().startswith('}'):
                        break
                    lines[j] = re.sub(r'\bit\.', '_it.', lines[j])
                    lines[j] = re.sub(r'\bit\)', '_it)', lines[j])
        content = '\n'.join(lines)

    if content != original:
        with open(fpath, 'w') as f:
            f.write(content)
        print(f"Fixed: {fname}")

# === PHASE 3: Add missing interface stubs ===
STUBS_PATH = os.path.join(SRC, '_stubs.cj')
stubs_needed = []
# Check which interfaces are referenced but not defined
all_content = ""
for fname in sorted(os.listdir(SRC)):
    if fname.endswith(".cj"):
        with open(os.path.join(SRC, fname)) as f:
            all_content += f.read()

stub_defs = []
if 'AutoCloseable' in all_content:
    stub_defs.append('interface AutoCloseable {\n    func close(): Unit\n}')
if 'MutableIterator' in all_content:
    stub_defs.append('interface MutableIterator<T> {\n    func hasNext(): Bool\n    func next(): T\n}')
if 'MutableMap' in all_content:
    stub_defs.append('''open class MutableMap {
    public open func containsKey(key: Any): Bool { return false }
    public open func containsValue(value: Any): Bool { return false }
    public open func get(key: Any): ?Any { return None }
    public open func isEmpty(): Bool { return true }
    public open func clear(): Unit {}
    public open func put(key: Any, value: Any): ?Any { return None }
    public open func putAll(from: Any): Unit {}
    public open func remove(key: Any): ?Any { return None }
}''')
    stub_defs.append('''open class MutableEntry<K, V> {
    var key: K
    var value: V
    init() { this.key = key; this.value = value }
    init(k: K, v: V) { this.key = k; this.value = v }
    public open func setValue(newValue: V): V { return newValue }
}''')

if stub_defs:
    with open(STUBS_PATH, 'w') as f:
        f.write('package ksoup_cj\n\nimport std.collection.*\n\n')
        f.write('\n\n'.join(stub_defs))
        f.write('\n')
    print(f"Created _stubs.cj with {len(stub_defs)} interface stubs")

print("\nAll fixes applied.")
