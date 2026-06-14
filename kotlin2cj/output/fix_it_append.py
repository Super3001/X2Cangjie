#!/usr/bin/env python3
"""Fix remaining `let it = _also_it` and `let append = append` shadowing issues."""
import os, re

SRC = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

# Fix: let it = _also_it -> remove line, use _also_it
for fname in os.listdir(SRC):
    if not fname.endswith(".cj"):
        continue
    fpath = os.path.join(SRC, fname)
    with open(fpath) as fh:
        content = fh.read()

    original = content

    # Fix `let it = _also_it`
    if 'let it = _also_it' in content:
        # Replace the pattern: let it = _also_it\n ... use _also_it
        # Strategy: rename `it` after this line to `_also_it` within scope
        lines = content.split('\n')
        new_lines = []
        skip_next_refs = False
        for i, line in enumerate(lines):
            if re.match(r'^\s+let it = _also_it\s*$', line):
                # Remove this line
                skip_next_refs = True
                continue
            if skip_next_refs:
                # Replace `it.xxx` or `it =` or `it)` or `it,` with `_also_it.xxx` etc
                # But only within this block (until we hit a closing brace or return)
                if re.match(r'^\s+return', line) or re.match(r'^\s+\}', line):
                    skip_next_refs = False
                else:
                    line = re.sub(r'\bit\.', '_also_it.', line)
                    line = re.sub(r'\bit\)', '_also_it)', line)
                    line = re.sub(r'\bit,', '_also_it,', line)
                    line = re.sub(r'\(it\)', '(_also_it)', line)
            new_lines.append(line)
        content = '\n'.join(new_lines)

    # Fix `let append = append.replace(...)` (parameter shadowing)
    # Rename local variable to `_result`
    content = re.sub(
        r'let append = append\.replace\(',
        'let _result = append.replace(',
        content
    )
    # If append was used standalone after, also fix
    content = re.sub(
        r'appendTagName\(append\)', 'appendTagName(_result)',
        content
    )
    content = re.sub(
        r'appendAttributeName\(append,', 'appendAttributeName(_result,',
        content
    )

    if content != original:
        with open(fpath, 'w') as fh:
            fh.write(content)
        print(f"Fixed: {fname}")
