# Changelog

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
