#!/usr/bin/env python3
"""Read _stubs.cj, remove types that exist in other .cj files. Add missing external types."""
import os, re

SRC = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

# Read all defined types from .cj files (excluding _stubs.cj)
defined = set()
for f in sorted(os.listdir(SRC)):
    if f.endswith('.cj') and f != '_stubs.cj':
        with open(os.path.join(SRC, f)) as fh:
            for line in fh:
                m = re.match(r'^\s*(open\s+|public\s+|abstract\s+)*(class|interface|enum)\s+(\w+)', line)
                if m:
                    defined.add(m.group(3))

print(f"Defined types: {sorted(defined)}")

# Read stubs
stub_path = os.path.join(SRC, '_stubs.cj')
with open(stub_path) as fh:
    stubs_content = fh.read()

# Identify stub types that conflict
stub_types = set()
for m in re.finditer(r'^\s*(open\s+|public\s+)*(class|interface|enum)\s+(\w+)', stubs_content, re.MULTILINE):
    stub_types.add(m.group(3))

conflicts = stub_types & defined
print(f"Stub types: {sorted(stub_types)}")
print(f"CONFLICTS (in stubs AND defined elsewhere): {sorted(conflicts)}")

# Remove conflicting type blocks from stubs
for conflict in conflicts:
    # Remove the entire type definition block
    pattern = rf'(open\s+|public\s+|abstract\s+)*(class|interface|enum)\s+{conflict}[^{{]*\{{[^}}]*\}}\n*'
    stubs_content = re.sub(pattern, '', stubs_content, flags=re.DOTALL)

# Now build to see which types are truly undeclared
with open(stub_path, 'w') as fh:
    fh.write(stubs_content)

print(f"\nCleaned stubs. Removed {len(conflicts)} conflicting types.")
print(f"Remaining stubs content:\n{stubs_content}")
