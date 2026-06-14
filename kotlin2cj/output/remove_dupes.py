#!/usr/bin/env python3
"""Remove KMP duplicate .cj files from ksoup output.
KMP actual implementations (src@jvm/, src@native/, etc.) produce
classes with the same names as expect declarations (src/).
Keep only main implementations, remove platform-specific alternates.
"""
import os, sys, re

SRC = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

# KMP platform duplicates — remove all except the main one (platform.cj)
KMP_DUPES = [
    'platform.android.cj', 'platform.android_native.cj',
    'platform.apple.cj', 'platform.js.cj', 'platform.jvm.cj',
    'platform.linux.cj', 'platform.mingw.cj', 'platform.wasm_js.cj',
    'weak_reference.js.cj', 'weak_reference.native.cj', 'weak_reference.wasm.cj',
]

removed = []
for fname in KMP_DUPES:
    fpath = os.path.join(SRC, fname)
    if os.path.exists(fpath):
        os.remove(fpath)
        removed.append(fname)

# Fix evaluator.cj: rename inner classes Tag -> EvalTag, Attribute -> EvalAttribute
# These conflict with top-level Tag and Attribute classes
evaluator_path = os.path.join(SRC, "evaluator.cj")
if os.path.exists(evaluator_path):
    with open(evaluator_path) as fh:
        content = fh.read()
    # Rename class Tag inside evaluator (inner class of Evaluator)
    new_content = content.replace("class Tag <: Evaluator", "class EvalTag <: Evaluator")
    new_content = new_content.replace("class Attribute <: Evaluator", "class EvalAttribute <: Evaluator")
    # Update all references
    # Tag references within evaluator context
    new_content = new_content.replace("return Tag(", "return EvalTag(")
    new_content = new_content.replace("= Tag(", "= EvalTag(")
    new_content = new_content.replace("case Tag =>", "case EvalTag =>")
    new_content = new_content.replace("Evaluator.Tag(", "Evaluator.EvalTag(")
    new_content = new_content.replace("Attribute(", "EvalAttribute(")
    new_content = new_content.replace("case Attribute =>", "case EvalAttribute =>")

    if new_content != content:
        with open(evaluator_path, "w") as fh:
            fh.write(new_content)
        removed.append("evaluator.cj (renamed Tag -> EvalTag, Attribute -> EvalAttribute)")

print(f"Removed/fixed: {removed}")
print(f"Remaining .cj files: {len([f for f in os.listdir(SRC) if f.endswith('.cj')])}")
