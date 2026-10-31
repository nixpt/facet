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

## Engine envelope

Pure Crush over stdlib caps only (`sys.args`, `sys.exit`, `io.print`,
`env.get`, `conv.*`, `str.*`). No engine-specific paths. Verified the same
way this repo's string machinery was: PortableVM + scheduler + both AOT
backends must print identical output (unicode scalars — `日`, emoji — may
appear in args and must survive untouched; slices/indexing in 0.9.0 are
char-based by contract).

## Test strategy

`facet_test.crush` asserts every rule: bundling, `--` escape, unknown flag,
bad int/float, choices violation, required missing, defaults, `--` in
options, repeat positionals, subcommand dispatch, help rendering exit
parity, env fallback. Cross-engine: `crush-diff` over test + demo
(expect: PortableVM ≈ AOT).
