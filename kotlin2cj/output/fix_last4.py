#!/usr/bin/env python3
import os, re

SRC = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

# Fix 1: character_reader.cj — remove extend inside class, fix binarySearch call
fpath = os.path.join(SRC, "character_reader.cj")
with open(fpath) as f: c = f.read()
c = re.sub(r'\n    extend Array<Rune> \{\n        func binarySearch\(c: Rune\): Int64 \{\n            return this\.indexOf\(c\)\n        \}\n    \}\n', '\n', c)
c = c.replace('chars.binarySearch(c)', 'chars.indexOf(c)')
with open(fpath, 'w') as f: f.write(c)

# Fix 2: attributes.cj — keys() to keys
fpath = os.path.join(SRC, "attributes.cj")
with open(fpath) as f: c = f.read()
c = c.replace('attributes.keys() = keys.copyOf', 'attributes.keys = keys.copyOf')
with open(fpath, 'w') as f: f.write(c)

# Fix 3: entities.cj — backtick public enum value
fpath = os.path.join(SRC, "entities.cj")
with open(fpath) as f: c = f.read()
c = c.replace('| ascii | utf | fallback | public', '| ascii | utf | fallback | `public`')
c = c.replace('case public =>', 'case `public` =>')
with open(fpath, 'w') as f: f.write(c)

print("Fixed 3 files")
