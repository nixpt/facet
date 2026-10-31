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

## A whole CLI in one call

```crush
fn main() {
    // keep each map literal on one line until crush-ast CRUSH-345 lands
    let add = { name: "add", help: "add an item", options: [ { short: "-p", long: "--priority", type: "int", default: 1, choices: [1, 2, 3], help: "1 = low, 3 = urgent" } ], positionals: [ { name: "text", required: true, help: "what to do" } ] }
    let list = { name: "list", help: "show items", flags: [ { short: "-a", long: "--all", help: "include done items" } ] }
    let spec = { name: "todo", version: "0.2.0", about: "A tiny todo list.", subcommands: [add, list] }

    facet_run(spec, { add: |args| => cmd_add(spec, args), list: |args| => cmd_list(args) })
}
```

That gives `todo --help`, `todo --version`, `todo add --help` (the
subcommand's own options), typed and validated arguments, and exit status
0 / 2 everywhere, with no other code. Full program: [`demo/todo.crush`](demo/todo.crush).

## API

| function | behavior |
|---|---|
| `facet_run(spec, handlers)` | `facet_parse` + `facet_dispatch`: the whole CLI in one call |
| `facet_parse(spec)` | parse `sys.args()`. Bad input ⇒ `facet: <name>: <error>` + usage (the subcommand's, if the error is in one) + `exit(2)`. `-h`/`--help` ⇒ full help (or the subcommand's after it) + `exit(0)`. `--version`/`-V` ⇒ `name version` + `exit(0)` when the spec has `version`. A spec with problems ⇒ `facet: spec error: …` + `exit(70)` |
| `facet_dispatch(spec, handlers, args)` | call `handlers[args.subcommand]` (or `handlers.main` without subcommands) with `args`, return its result; no handler ⇒ `exit(70)` |
| `facet_fail(spec, message)` | your own argument check, reported like facet's: message + usage + `exit(2)` |
| `facet_resolve(spec, argv)` | what argv asks for, without printing or exiting: `{ action: "help" \| "version" \| "error" \| "run", text?, args?, spec? }` |
| `facet_parse_debug(spec, argv)` | the parse alone over an argv array: `{ ok, data, error }` (embedders + tests) |
| `facet_check_spec(spec)` | problems in a spec as lines (`[]` when fine): unknown keys such as `requried`, entries without `long`/`short`, a positional without `name`, an unknown option `type` |
| `facet_usage(spec)` / `facet_help(spec)` | the one-line usage / the full help text |
| `facet_version_text(spec)` | `name version` (`""` without `version`) |

Handlers are closures or function references stored in a map:
`{ add: |args| => do_add(args) }` or `{ main: run }`. (Call them through
`facet_run`/`facet_dispatch`: `handlers.add(args)` directly hits crush-ast
#362.)

Result map keys come from `long` (`--build-dir` ⇒ `build_dir`) unless the
entry sets `name`. Declared-but-unset options/positionals are present as
`null`; flags are `false`. `_provided` lists the keys that actually came
from argv (used by env fallback; handy for scripts).

## Spec entries

```
spec:        { name, usage?, version?, about?, epilog?,
               flags?, options?, positionals?, subcommands? }
flags:       { short?, long?, name?, default?, required?, help? }        // boolean
options:     { short?, long?, name?, type?, default?, required?,        // type: str|int|float|bool
               choices?, env?, help? }
positionals: { name, type?, default?, required?, repeat?, help? }
subcommands: { name, usage?, help?, about?, epilog?, flags?, options?, positionals? }
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
