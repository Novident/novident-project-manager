# Novident Project Manager — Documentation

Guide to the Dart package that owns the `.nov` schema and drives the Rust
engine. New here? Start with the **README**, then **ARCHITECT.md**, then
`getting-started.md`.

## Where to find what

| Doc | Quadrant (Diátaxis) | Purpose |
|---|---|---|
| `getting-started.md` | Tutorial | Setup, codegen, build, running tests, first open |
| `engine.md` | Explanation | How the Rust engine works and the JSON boundary |
| `project-format.md` | Explanation/Reference | The `.nov` format, file by file |
| `models.md` | Reference | Every schema class + codec, with field rules |
| `parsers-to-ast.md` | Explanation/Reference | Layout/editor → AST parsers: usage and output formats |
| `placeholders.md` | Reference | Every placeholder token and its syntax |
| `stores-and-reducer.md` | Reference | I/O interfaces, stores, reducer operations |
| `dart-classes-touch-plan.md` | Plan | Class-by-class schema migration roadmap |
| `git-snapshots-complete-plan.md` | Plan | Engine git + snapshot façade wiring roadmap |

## Also read

- `AGENTS.md` — working rules, layout, non-negotiables (maintainers + AI agents).
- `ARCHITECT.md` — end-to-end architecture (Dart ⇄ Rust).
- `SECURITY.md` / `CONTRIBUTING.md` — reporting, standards, contribution flow.
- `rust/docs/` — deep engine reference (format spec, engine redesign, git
  versioning). Some are kept in Spanish; the canonical rules are the ones
  enforced here (see `AGENTS.md`).
