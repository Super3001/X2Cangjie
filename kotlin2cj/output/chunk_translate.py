#!/usr/bin/env python3
"""Chunked translation for large .kt files that fail monolithic translation."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
KT = "/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt"
OUT = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src/element.cj"

with open(KT) as f:
    lines = f.readlines()

# Strategy: The header (lines 0-49) + body chunks (50 lines each)
# Each chunk is translated separately in a wrapper class
# Then combined into one file

header = "".join(lines[:49])  # package + imports + KDoc + class declaration

chunks = []
chunk_size = 50
for start in range(49, len(lines), chunk_size):
    end = min(start + chunk_size, len(lines))
    chunk_lines = lines[start:end]
    chunks.append("".join(chunk_lines))

# Translate each chunk
output_parts = []
for i, chunk in enumerate(chunks):
    if i == 0:
        code = header + chunk + "\n}\n"
    else:
        # Wrap in a dummy class for parsing
        code = "package com.fleeksoft.ksoup.nodes\nopen class Node\ninterface Iterable<T>\nclass _Wrap" + str(i) + " {\n" + chunk + "\n}\n"

    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out_tmp = f'/tmp/chunk_{i}.cj'
        r = subprocess.run([BIN, tmp, '-o', out_tmp], capture_output=True, text=True, timeout=30)
        if os.path.exists(out_tmp):
            with open(out_tmp) as fh:
                content = fh.read()
            if len(content) > 10:
                output_parts.append((i, content))
                print(f"  Chunk {i} (lines {49+i*chunk_size}-{49+min((i+1)*chunk_size, len(lines))}): {len(content)}B OK")
            else:
                print(f"  Chunk {i}: EMPTY (size={len(content)})")
        else:
            print(f"  Chunk {i}: NO OUTPUT")
    finally:
        os.unlink(tmp)

# Combine: first chunk has class declaration, others are class body content
combined = []
for i, content in output_parts:
    lines_chunk = content.split('\n')
    if i == 0:
        # Keep class declaration and opening brace
        combined.extend(lines_chunk)
    else:
        # Extract body content (between class { and })
        in_class = False
        brace_depth = 0
        for line in lines_chunk:
            if 'class _Wrap' in line:
                in_class = True
                continue
            if in_class:
                if '{' in line:
                    brace_depth += line.count('{')
                    if brace_depth == 1:
                        continue  # Skip opening brace
                if '}' in line:
                    brace_depth -= line.count('}')
                    if brace_depth <= 0:
                        break
                combined.append(line)

# Add closing brace for the Element class
combined.append('}')

with open(OUT, 'w') as f:
    f.write('\n'.join(combined))

print(f"\nCombined output: {len('\n'.join(combined))} bytes -> {OUT}")
