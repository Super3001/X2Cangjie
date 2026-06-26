#!/usr/bin/env python3
"""Post-processing fixes for target_1b translated output."""
import os, re, sys

TARGET = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/target_1b/src"

def fix_file(path):
    with open(path, 'r') as f:
        content = f.read()

    basename = os.path.basename(path)

    # Remove problematic stdlib imports
    content = content.replace('import std.convert.*\n', '')
    content = content.replace('import std.iterator.*\n', '')

    if basename == 'source_reader.cj':
        # Fix interface: remove ! and default values from params
        content = content.replace('offset!: Int64 = 0, length!: Int64 = bytes.size', 'offset: Int64, length: Int64')

    elif basename == 'source_reader_ext.cj':
        # Fix companion extension on interface
        content = re.sub(
            r'extend SourceReader\.Companion \{\s*func from\(byteArray: Array<Byte>\): SourceReader \{\s*return SourceReaderByteArray\(\[byteArray\]\)\s*\}\s*\}',
            'func sourceReaderFrom(byteArray: Array<Byte>): SourceReader {\n    return SourceReaderByteArray(byteArray)\n}',
            content
        )

    elif basename == 'source_reader_byte_array.cj':
        # Fix ByteArray constructor
        content = content.replace('let byteArray = ByteArray(count)', 'let byteArray = Array<Byte>(count)')
        content = content.replace('byteArrayOf()', 'Array<Byte>(0)')
        content = content.replace('byteArray.copyOfRange(0, i)', 'byteArray[0..i].copy()')

    elif basename == 'cleaner.cj':
        # Fix inner class scope: CleaningVisitor needs cleaner reference
        content = content.replace(
            'func copySafeNodes(source: Element, dest: Element): Int64 {\n        let cleaningVisitor = CleaningVisitor(source, dest)\n        cleaningVisitor.traverse(source)',
            'func copySafeNodes(source: Element, dest: Element): Int64 {\n        let cleaningVisitor = CleaningVisitor(this, source, dest)\n        let traversor = NodeTraversor(cleaningVisitor)\n        traversor.traverse(source)'
        )
        # Fix CleaningVisitor class: add cleaner field
        content = content.replace(
            'class CleaningVisitor <: NodeVisitor {\n    let root: Element\n    var destination: Element\n    init(root: Element, destination: Element) {',
            'class CleaningVisitor <: NodeVisitor {\n    let cleaner: Cleaner\n    let root: Element\n    var destination: Element\n    init(cleaner: Cleaner, root: Element, destination: Element) {\n        this.cleaner = cleaner'
        )
        # Fix safelist references in CleaningVisitor
        content = content.replace('if (safelist.isSafeTag', 'if (cleaner.safelist.isSafeTag')
        content = content.replace('let meta: ElementMeta = createSafeElement', 'let meta: ElementMeta = cleaner.createSafeElement')
        content = content.replace('&& safelist.isSafeTag', '&& cleaner.safelist.isSafeTag')
        # Also fix tail method
        content = content.replace('safelist.isSafeTag(node.normalName())) {\n            destination = destination.parent()',
                                  'cleaner.safelist.isSafeTag(node.normalName())) {\n            destination = destination.parent()')
        # Fix clone issue
        content = content.replace("clean.outputSettings(dirtyDocument.outputSettings().clone())",
                                  "clean.outputSettings(dirtyDocument.outputSettings())")
        # Fix baseUri optional
        content = content.replace("let dirty = Document.createShell(baseUri)\n",
                                  "let dirty = Document.createShell(baseUri.getOrThrow())\n")

    elif basename == 'safelist.cj':
        # Fix IIFE pattern: ({ => ... })() → proper let binding
        # pattern: let attr = ({ => ... })()  →  let attr = ...
        content = re.sub(r'let (\w+) = \(\{\s*=>\s*', r'let \1 = ', content)
        # Remove trailing })()
        content = content.replace(' })()', '')
        # Fix inner IIFE in else branch: let _v = ({ => HashSet() })();  → let _v = HashSet()
        content = re.sub(r'let _v = \(\{\s*=>\s*(\w+)\(\)\s*\}\)\(\)', r'let _v = \1()', content)
        # Fix lowerCase
        content = content.replace('lowerCase(', 'toAsciiLower(')
        # Fix copy.preserveRelativeLinks (var vs func)
        content = content.replace('copy.preserveRelativeLinks', 'copy.preserveRelativeLinks()')

    with open(path, 'w') as f:
        f.write(content)
    return basename

for f in sorted(os.listdir(TARGET)):
    if f.endswith('.cj') and f != 'main.cj' and f != '_stubs.cj':
        result = fix_file(os.path.join(TARGET, f))
        print(f"  Fixed: {result}")

print("Done.")
