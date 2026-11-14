#!/usr/bin/env bash
# facet self test: concatenate the library + tests, run on the CVM1 VM.
# Needs `crush-run` on PATH (crush-ast >= 0.9.0).
set -euo pipefail
cd "$(dirname "$0")/.."

CRUSH_RUN="${CRUSH_RUN:-crush-run}"
OUT="$(mktemp -d)/facet_test.crush"

cat facet.crush facet_test.crush > "$OUT"

# stdin </dev/null: never let a program block on an inherited pipe.
# stderr is shown (a runtime crash must print its message); the VM's
# `[steps=...]` noise lines are filtered out.
"$CRUSH_RUN" run "$OUT" < /dev/null 2> >(grep -v '^\[steps=' >&2)
