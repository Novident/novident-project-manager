# Contributing

Thank you for contributing to `novident_project_manager`. Please read
`AGENTS.md` (working rules + non-negotiables) and `ARCHITECT.md` before
starting.

## Communication

- **Bug reports / feature requests**: open an issue with the failing command,
  Dart/Rust versions, and a minimal repro.
- **Security issues**: follow `SECURITY.md` (private report).
- **Design discussions**: reference the docs (`docs/index.md`) and keep English.

## Development setup

1. Clone the repo.
2. `flutter pub get`.
3. Baseline: `dart analyze lib/` clean and both suites green:
   `flutter test` and `cargo test --manifest-path rust/Cargo.toml`.

## Making changes

1. **Pick a scope** and keep it small; prefer one concern per PR.
2. Follow the file/naming rules and code-quality expectations in `AGENTS.md`:
   - English everywhere (code, comments, docs, commits);
   - snake_case JSON keys mirroring Dart fields; tolerant `fromJson`;
   - no direct `NodeContainer.children` mutation; read node state through
     mixins;
   - `Binder*`/`Node*`/domain prefixes per the taxonomy.
3. **Tests first** where the change is pure logic; engine-backed changes get
   Rust tests (real temp repos) and Dart DTO/parse tests + `analyze`.
4. If you change a schema shape, update `assets/example.nov` and keep
   `test/golden/example_nov_golden_test.dart` green.
5. If you change `rust/src/api/manager.rs`, regenerate FRB
   (`flutter_rust_bridge_codegen generate`) — commit both generated outputs.
6. Never add dependencies without a written reason in the PR (see
   `AGENTS.md` non-negotiable 14).

## Commit style

- Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`,
  `chore:`.
- Subject ≤ 72 chars; body explains the *why* when it is not obvious.

## Definition of done (per PR)

- `dart analyze lib/` clean.
- `flutter test` and `cargo test` green.
- Golden fixture + golden test consistent.
- New public symbols documented (`///`), English, covered by tests.
- No import of the raw FRB binding outside `engine_client.dart`.

## Review checklist

- Correctness: does the code follow the store/adapter and façade patterns?
- Robustness: tolerant parsing, no crashes on missing keys, path checks kept.
- Tests: is the regression actually covered?
- Docs: does this need `docs/*`, `AGENTS.md` or `ARCHITECT.md` updates?
