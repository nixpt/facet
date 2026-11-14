#!/usr/bin/env bash
# facet checks: (1) every demo runs --help through the import form,
# (2) the self test: concatenate the library + tests (it needs the __facet_*
# internals, which cannot be imported) and run on the CVM1 VM.
# Needs `crush-run` (crush-ast >= 0.9.0, with CRUSH-110 imports).
set -euo pipefail
cd "$(dirname "$0")/.."

CRUSH_RUN="${CRUSH_RUN:-crush-run}"
TMP="$(mktemp -d)"

# 1. import form: `-L .` finds ./facet.crush. stdin </dev/null: never let a
# program block on an inherited pipe.
for demo in demo/greet.crush demo/todo.crush; do
    if "$CRUSH_RUN" run -L . "$demo" -- --help < /dev/null > "$TMP/help.out" 2>&1; then
        echo "ok   import --help: $demo"
    else
        echo "FAIL import --help: $demo"; cat "$TMP/help.out"; exit 1
    fi
done
# env_greet imports facet_env (import-only); --env goes before `--`.
if "$CRUSH_RUN" run -L . --env demo/env_greet.crush -- --help < /dev/null > "$TMP/help.out" 2>&1; then
    echo "ok   import --help: demo/env_greet.crush"
else
    echo "FAIL import --help: demo/env_greet.crush"; cat "$TMP/help.out"; exit 1
fi

# env_greet behaviour: env fills an unset option; argv beats env.
out="$(GREET_LEVEL=3 "$CRUSH_RUN" run -L . --env demo/env_greet.crush -- --name Ada < /dev/null 2>&1)" || true
if [ "$out" = "level=3 name=Ada" ]; then
    echo "ok   env fallback: $out"
else
    echo "FAIL env fallback: got '$out'"; exit 1
fi
out="$(GREET_LEVEL=3 "$CRUSH_RUN" run -L . --env demo/env_greet.crush -- --name Ada -l 2 < /dev/null 2>&1)" || true
if [ "$out" = "level=2 name=Ada" ]; then
    echo "ok   argv beats env: $out"
else
    echo "FAIL argv beats env: got '$out'"; exit 1
fi

# 2. self test (last line: "all facet checks passed").
cat facet.crush facet_test.crush > "$TMP/facet_test.crush"
"$CRUSH_RUN" run "$TMP/facet_test.crush" < /dev/null 2>/dev/null
