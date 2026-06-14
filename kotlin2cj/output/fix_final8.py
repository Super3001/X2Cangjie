#!/usr/bin/env python3
import os

SRC = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

# entities.cj: add types, fix public enum, remove extend in class
f = os.path.join(SRC, "entities.cj")
with open(f) as fh: c = fh.read()
c = c.replace('    let empty\n', '    let empty: Any\n')
c = c.replace('    let codeDelims\n', '    let codeDelims: Any\n')
c = c.replace('    let LocalEncoder\n', '    let LocalEncoder: Any\n')
c = c.replace('| ascii | utf | fallback | public', '| ascii | utf | fallback | `public`')
c = c.replace('case public =>', 'case `public` =>')
with open(f, 'w') as fh: fh.write(c)

# attributes.cj: keys() to keys
f = os.path.join(SRC, "attributes.cj")
with open(f) as fh: c = fh.read()
c = c.replace('attributes.keys() = keys.copyOf', 'attributes.keys = keys.copyOf')
with open(f, 'w') as fh: fh.write(c)

# character_reader.cj: remove extend inside class, fix binarySearch
f = os.path.join(SRC, "character_reader.cj")
with open(f) as fh: c = fh.read()
# Remove extend block inside class
import re
c = re.sub(r'    extend Array<Rune> \{\n        func binarySearch\(c: Rune\): Int64 \{\n            return this\.indexOf\(c\)\n        \}\n    \}\n', '', c)
c = c.replace('chars.binarySearch(c)', 'chars.indexOf(c)')
# Fix spurious closing brace left by regex
c = re.sub(r'\n    }\n    func consumeToAnySorted', '\n    func consumeToAnySorted', c)
with open(f, 'w') as fh: fh.write(c)

print("Fixed entities, attributes, character_reader")
