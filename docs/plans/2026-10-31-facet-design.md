# facet — design

**One-liner:** CLI argument parser and help renderer for Crush programs, written
in Crush. Like argparse/click, but for the Crush language, tailored to its
spec-map idiom.

## Decisions (confirmed in brainstorm 2026-10-31)

- **Name/nameplate:** `facet` — a cut stone's surfaces; the library cuts raw
  `sys.argv()` into declared facets.
- **Home:** standalone repo `/workspace/projects/facet`, packaged via
  `capsule.toml` (crush-pkg installable), not a crush-ast crate — release
  cadence independent of the toolchain.
- **API shape:** one declarative spec map (matches Crush's map-literal
  idiom, cf. sysinfo/blackjack), NOT a builder chain.
- **Scope v0.1 = the full kit:** flags, typed options, positionals (incl.
  repeatable), `--` escape, `-abc` bundling, required/defaults/auto-help,
  choices validation, env-var fallback, subcommands.
- **Error policy:** parse problems print `facet: <error>` + usage and exit 2
  automatically (argparse convention); `facet.err()` exposes the last error
  for embedding callers.

## Modules

```
facet/
  main.crush       # barrel: facet.parse(), facet.usage(), facet.err()
  spec.crush       # spec validation + normalization + defaults
  lex.crush        # argv tokenizer: flags, --name=v, bundling, -- escape
  coerce.crush     # typed values: str/int/float/bool, choices, env fallback
  render.crush     # usage + --help text, column-aligned
  facet_test.crush # self-verify program (every rule asserted)
  demo/            # sample CLI exercising subcommands + env fallback
```

## Spec map contract

```
{
  name: "greet", usage: "greet [options] [names...]",   // name required, usage optional
  flags:      [ { short: "-v", long: "--verbose", help: "..." } ],        // booleans
  options:    [ { long: "--level", short: "-l", type: "int",              // str|int|float|bool
                  default: 1, choices: [1, 2], env: "GREET_LEVEL",
                  required: false, help: "..." } ],
  positionals:[ { name: "names", repeat: true, default: [] } ],
  subcommands:[ { name: "add", usage: "...", flags: [...], options: [...],
                  positionals: [...] } ]   // optional; when present the first
                                           // non-flag token must be one of them
}
```
Result keys: derived from `long` (`--build-dir` → `build_dir`) or explicit
`name`; insertion-ordered map output; `args.subcommand` present when a
subcommand matched.

## Packaging reality (pinned by engine probes, 2026-10-31)

- Crush has **no working source-level module imports** (`import x` compiles to
  a `module.load` cap call that no backend implements). crush-pkg's
  `collect_all_sources` ships only the capsule **entry** file (or `src/**`),
  and `build` concatenates path-dep entries into one program. Therefore facet
  distributes as **one flat file** (`facet.crush = entry`) whose functions are
  global: `facet_parse`, `facet_parse_debug`, `facet_usage`, `facet_help`.
- **AOT backends cannot compile `try/catch` or `env.get` at all** — even in an
  unused function (probed: C backend rejects `enter_try`/`exit_try`/`env.get`
  loudly; failure is compile-wide, not reachability-based). So the core must
  contain neither. Env fallback lives in a separate opt-in companion
  (`facet_env.crush`, own package) documented as VM-only until the AOT gap
  closes.
- The whole-program capability grant check IS reachability-aware (an unused
  `env.get` function does not force `--env`), so companion code doesn't gate
  consumers that never call it — but compile support is not, hence split.

## Semantics pinned

- Flags are boolean only (presence ⇒ true). Options take a value from the
  next token or `--name=value`; remaining bundle chars after an option's
  short in `-lv5` become its value.
- `--` ends options; everything after is positional-only.
- `-abc` bundles three boolean shorts.
- Coercion: int via base-10 parse (rejects garbage, floors nothing),
  float validates shape then converts, bool accepts only true/false.
- `--help`/`-h`: rendered spec, exit 0 (only when the spec has not claimed
  that exact flag itself).
- env fallback: consulted only when unset AND no default; wrapped so a run
  without the env capability stays alive (documented: needs `--env` to act).

## Engine envelope — measured, not assumed (2026-10-31)

- **PortableVm + scheduler (CVM1): fully verified.** `facet_test.crush` runs
  77 checks green; demo CLIs (`--help`, success, unknown option, missing
  required) produce argparse-grade output and exit codes 0/2.
- **FastVM / JIT:** share the same registered capability implementations
  (`conv.*`, `str.*`, `seq.slice`, `sys.*`); the differential harness cannot
  wire capabilities into FastVM yet (it abstains), so facet's FastVM claim is
  "same code path, untested" — do not advertise more.
- **AOT: blocked upstream.** Measured via `crush-aotc`:
  - Rust lowerer rejects `sys.args`, `sys.exit`, `conv.parse_int`,
    `conv.to_float`, `conv.to_str` — a CLI library cannot avoid these.
  - C backend additionally rejects `enter_try`/`exit_try` and `env.get`
    outright (compile-wide, even unused) plus its prove-string analysis
    (`CRUSH-xps-13`) on dynamic-text caps.
  - Therefore `facet.crush` keeps **no** `try/catch`, **no** `env.get`;
    env fallback ships as the plain companion file `facet_env.crush`
    (concatenate it explicitly; needs `--env` at run time). When the AOT
    lowerers learn these caps, the envelope widens with no facet change.

## Env fallback precedence

**argv > env > default.** The parse result carries `_provided` (keys that
came from argv); `facet_env_apply(spec, args)` fills only options not in
`_provided`, and only when the env text coerces cleanly. Consequences:
options with `env:` can't be `required:` in the same breath (required is
checked from argv alone) — declare a default instead, or check it yourself.


## Test strategy

`facet_test.crush` asserts every rule: bundling, `--` escape, unknown flag,
bad int/float, choices violation, required missing, defaults, `--` in
options, repeat positionals, subcommand dispatch, help rendering exit
parity, env fallback. Cross-engine: `crush-diff` over test + demo
(expect: PortableVM ≈ AOT).
