# facet

CLI argument parser and help renderer for **Crush** programs — like
Python's `argparse`/`click`, but in the Crush language, for the Crush
language, driven by one declarative spec map.

```crush
use "facet"

let spec = {
    name: "greet",
    usage: "greet [options] [names...]",
    flags:     [ { short: "-v", long: "--verbose", help: "chatty" } ],
    options:   [ { long: "--level", short: "-l", type: "int", default: 1,
                   choices: [1, 2], env: "GREET_LEVEL", help: "verbosity" } ],
    positionals: [ { name: "names", repeat: true, default: [] } ]
}

let args = facet.parse(spec)     // bad input ⇒ error + usage + exit(2)
print("level is " + args.level)
```

Run `facet_test.crush` with any engine:

    crush-run run facet_test.crush

Design: `docs/plans/2026-10-31-facet-design.md`. Needs crush-ast ≥ 0.9.0
(source-level string slices are char-based there).
