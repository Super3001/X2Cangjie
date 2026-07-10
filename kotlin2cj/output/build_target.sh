#!/usr/bin/env bash
# Encoding-safe `cjpm build` wrapper for measurement pipelines.
#
# WHY: PowerShell `>` / Out-File re-encodes the cjc stream and corrupts the
# ESC byte (0x1B) into literal escape sequences, breaking cluster diagnosis.
# Git Bash raw-byte `> ... 2>&1` preserves the original UTF-8 bytes.
#
# Do NOT manipulate PATH here — cjpm/cjc are resolved from the inherited
# Windows PATH (cjpm found at C:\toolchain\Cangjie1.0.5\tools\bin). Forcing
# a PATH inside this script shadows DLL search and breaks cjpm.exe load.
#
# Usage (from PowerShell):
#   & "C:\Users\songy\scoop\apps\git\current\bin\bash.exe" `
#       "C:\Codes\X2Cangjie\kotlin2cj\output\build_target.sh" `
#       "C:\Codes\X2Cangjie\kotlin2cj\output\target_1g_r19"
#
# Args:
#   $1 = absolute Windows path to the target dir containing cjpm.toml
#   $2 = (optional) extra args passed to cjpm build
set -u
target="$1"
if [ -z "$target" ] || [ ! -d "$target" ]; then
  echo "usage: build_target.sh <target-dir-with-cjpm.toml> [extra-cjpm-args]" >&2
  exit 2
fi
shift || true
# Convert C:\...\dir -> /c/.../dir for git bash cd
unix_target=$(cygpath -u "$target" 2>/dev/null || echo "$target")
cd "$unix_target" || { echo "cd failed: $unix_target" >&2; exit 2; }
# Raw-byte redirect — NOT PowerShell Out-File.
cjpm build "$@" > compile.log 2>&1
rc=$?
echo "CJPM_EXIT=$rc"
exit $rc
