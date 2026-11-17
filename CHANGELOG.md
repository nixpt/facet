# Changelog

## Unreleased

### Changed
- Visibility stage 2 (crush-ast#520, FACET-11): the API is marked `pub`:
  `facet_run`, `facet_parse`, `facet_resolve`, `facet_dispatch`, `facet_fail`,
  `facet_help`, `facet_usage`, `facet_version_text`, `facet_check_spec`,
  `facet_parse_debug` and `facet_env_apply`. Every other name (the `__facet_*`
  helpers, `facet_key`, `facet_coerce_value`) is private to the directory, and
  importers no longer get the `N-VIS01` note. Needs a crush-ast with `pub`
  (after 0.11.2).
- Layout: `demo/` moved to `examples/demo/`, and `test/` plus `facet_test.crush`
  moved to `tests/`, so programs with helpers sit outside the gated tree;
  `crush-pkg build --deny-legacy-visibility` passes.

## 0.3.0 — 2026-11-14

### Added
- Count flags: `count: true` on a flag gives an int (`-vvv` = 3); flags only,
  no `type`/`default`, `--flag=N` is an error, help notes "(repeatable)".
- Option groups: spec key `groups` (`exclusive`, `together`, `one_of`), at top
  level and on subcommands; checked after required/choices, argv-given only.

### Changed
- Import-first docs and demos (FACET-4): README leads with `import facet { ... }`
  plus `crush-run run -L`, then a crush-pkg path dep, then concatenation as the
  fallback. `demo/greet`, `demo/todo` and `examples/consumer` use the import form.
- `test/run.sh` also runs each demo's `--help` and fails if any exits non-zero.
- facet_env is import-only; it imports facet itself (and keeps private copies of two
  tiny helpers). Concatenating it with `facet.crush` now collides. `demo/env_greet`
  uses `import`, and `test/run.sh` runs it with `-L . --env`.
- Dropped the stale "no imports" and CRUSH-348/349 caveats.

### Fixed
- `demo/env_greet.crush` header: `--env` goes before `--` (and is needed even
  for `--help`).

## 0.2.1 — 2026-11-14

### Fixed
- A required repeating positional (`repeat: true, required: true`) now needs at
  least one value: with none it fails with `missing required argument '<name>'`
  instead of parsing to an empty list (#2).

## 0.2.0 — 2026-10-31

### Added
- `facet_run(spec, handlers)`: parse and dispatch to a handler per subcommand
  (`handlers.main` without subcommands), so a CLI is one call.
- `facet_dispatch`, `facet_fail` (your own checks, reported like facet's),
  `facet_resolve` (help / version / error / run without printing),
  `facet_check_spec`, `facet_version_text`.
- Spec keys `version` (`--version`/`-V`), `about` (shown under the usage
  line) and `epilog` (shown last), also on subcommands.
- `prog sub --help` shows the subcommand's own help.
- `demo/todo.crush`: a two-command CLI built with `facet_run`.

### Changed
- `facet_parse` checks the spec first and refuses one with problems (unknown
  keys, missing `long`/`short`/`name`, an unknown `type`) with exit 70, where
  typos used to be ignored silently.
- A parse error inside a subcommand prints that subcommand's usage line.
- Help text never ends in a blank line.

## 0.1.1 — 2026-10-31

### Fixed
- A positional's `help` is shown in `--help`; entries without `help` no
  longer print `null`.

## 0.1.0 — 2026-10-31

First version: flags, typed options, positionals, `--`, bundling,
required/defaults, choices, env fallback (`facet_env.crush`), subcommands.
