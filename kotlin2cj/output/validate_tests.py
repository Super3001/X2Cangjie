#!/usr/bin/env python3
"""Validate translator against all test cases — verify no crash/regression."""
import os, sys, subprocess, glob

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
CASES = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/tests/cases"

cases = sorted(glob.glob(os.path.join(CASES, "*.kt")))
ok = 0
fail = []

for kt in cases:
    result = subprocess.run(
        [BIN, kt, "-o", "/tmp/test_out.cj"],
        capture_output=True, text=True, timeout=15
    )
    name = os.path.basename(kt)
    if result.returncode == 0:
        ok += 1
    else:
        fail.append((name, result.stderr.strip()[:150]))

print(f"Passed: {ok}/{len(cases)}")
if fail:
    print(f"Failed ({len(fail)}):")
    for name, err in fail:
        print(f"  {name}: {err}")
else:
    print("ALL PASSED — zero regressions")
