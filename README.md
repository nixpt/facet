# facet

CLI argument parser and help renderer for **Crush** programs — like
Python's `argparse`/`click`, but in the Crush language, for the Crush
language, driven by one declarative spec map.

```crush
// one spec map drives parsing, defaults, usage, --help, subcommands
let spec = { name: "greet", usage: "greet [options] [files...]", flags: [ { short: "-v", long: "--verbose", help: "say more" } ], options: [ { long: "--level", short: "-l", type: "int", default: 1, choices: [1, 2, 3], help: "verbosity" }, { long: "--name", type: "str", required: true, help: "who" } ], positionals: [ { name: "files", repeat: true, help: "extra files" } ] }

let args = facet_parse(spec)     // bad input ⇒ error + usage + exit(2)
io.print("Hello, " + args.name + " (level " + conv.to_str(args.level) + ")")
```

That yields `--help`, `-vh`-style bundling, `--level=2`/`-l2`/`-l 2`,
positional collection, typed defaults and column-aligned help — all from
the spec. Runnable examples in [`demo/`](demo/).

> **Crush has no source-level imports yet** (`module.load` is unimplemented
> upstream). Consume facet either way:
>
> **1. Concatenate** (one-off scripts):
> ```sh
> cat facet.crush my_program.crush > /tmp/my_program.crush
> crush-run run /tmp/my_program.crush -- --help
> ```
>
> **2. crush-pkg path dependency** (projects — see
> [`examples/consumer/`](examples/consumer)):
> ```toml
> [[dependencies]]
> name = "facet"
> path = "../facet"
> ```
> ```sh
> crush-pkg build
> crush-run run target/<name>.cvm -- --help
> ```
> Known upstream limits (crush-ast CRUSH-348/349, 2026-10-31): `crush-pkg run`
> does not see path deps, and crush-pkg turns `sys.exit(n)` into an E-RUN
> failure while dropping pre-exit output — run the built `.cvm` with
> `crush-run` until those land.
>
> Functions are global by design; everything internal is `__facet_`-prefixed.

## API

| function | behavior |
|---|---|
| `facet_parse(spec)` | parse `sys.args()`; bad input ⇒ `facet: <name>: <error>` + usage + `exit(2)`; `-h`/`--help` ⇒ full help + `exit(0)` |
| `facet_parse_debug(spec, argv)` | same parse over an argv array; returns `{ ok, data, error }` and never prints or exits (embedders + tests) |
| `facet_usage(spec)` | one-line `Usage: …` |
| `facet_help(spec)` | full help text |

Result map keys come from `long` (`--build-dir` ⇒ `build_dir`) unless the
entry sets `name`. Declared-but-unset options/positionals are present as
`null`; flags are `false`. `_provided` lists the keys that actually came
from argv (used by env fallback; handy for scripts).

## Spec entries

```
flags:       { short?, long?, name?, default?, required?, help? }        // boolean
options:     { short?, long?, name?, type?, default?, required?,        // type: str|int|float|bool
               choices?, env?, help? }
positionals: { name, type?, default?, required?, repeat?, help? }
subcommands: { name, usage?, help?, flags?, options?, positionals? }
```

Semantics: `--` ends option parsing; `-abc` bundles boolean shorts;
`-lv5` = `-l v5`; unknown option / missing value / bad type / choices miss /
missing required ⇒ exit 2. Options with `env:` need the
[`facet_env.crush`](facet_env.crush) companion (`facet_env_apply(spec, args)`,
precedence **argv > env > default**, requires `--env`).

## Engine support

- **PortableVm / scheduler (CVM1): fully verified** — 77-check self test plus
  demo runs (`crush-run`).
- **FastVM / JIT:** same shared capability implementations; the differential
  harness cannot yet wire capabilities for FastVM (it abstains), so untested.
- **AOT backends: blocked upstream, not by facet** — the Rust AOT lowerer
  currently rejects `sys.args`, `sys.exit` and `conv.*`; the C AOT backend
  rejects dynamic-text caps and cannot compile `try/catch` or `env.get` at all
  (`CRUSH-xps-13`). `facet.crush` deliberately contains no `try/catch` and no
  `env.get` so that consumers are not gated further; env fallback lives in the
  separate companion.

## Tests

```sh
./test/run.sh
```

Concatenates `facet.crush` + `facet_test.crush` and runs the self test (needs
`crush-run` on PATH). Design notes:
[`docs/plans/2026-10-31-facet-design.md`](docs/plans/2026-10-31-facet-design.md).
Requires crush-ast ≥ 0.9.0.
