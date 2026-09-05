# AGENTS.md — Novident Project Manager

Working guide for AI agents and humans maintaining this repository.

## What this is

`novident_project_manager` is the Dart package that owns the **schema** of a
`.nov` writing project and delegates the heavy lifting to a **Rust engine**
(compiled via `flutter_rust_bridge`). The repo contains the Dart package, the
Rust crate (`rust/` + `rust_builder/`), the schema contract, tests, and the
`example.nov` golden fixture.

```
Dart (schema owner)  ⇄  JSON boundary  ⇄  Rust engine (I/O, git, search, diff, snapshots, validation)
```

## Repository layout

```
lib/
├── novident_project_manager.dart     # public barrel (EngineClient, EngineTypes, ProjectManager)
├── src/
│   ├── engine/                       # EngineClient (only FRB importer) + engine_types DTOs
│   ├── project_manager.dart          # ProjectManager façade (lifecycle, stores, reducer conveniences)
│   ├── project/                      # Dart schema layer: models, codecs, stores, adapters
│   │   ├── author/ section/ target/ icon/ corkboard/ session/ export/ backup/ comments/
│   │   ├── binder_types.dart       # typed LookupEntry + ExternalFile (lookup/external_files)
│   │   ├── binder_codec.dart       # binder.index.json ⇄ novident_nodes tree
│   │   ├── binder_store.dart       # BinderIo + BinderStore (header-preserving persistence)
│   │   ├── collection_store.dart   # generic collection store (exports, sessions, …)
│   │   ├── content_codec.dart      # content.json + synopsis.json (editor Document)
│   │   ├── content/text_count.dart # word/char/no-spaces counting
│   │   ├── document_cache.dart     # DocumentIo + LRU debounced content cache
│   │   ├── format_store.dart       # CompilerIo + formats/layouts lazy host
│   │   ├── engine_adapters.dart    # Engine*Io adapters over EngineClient
│   │   ├── sections_codec.dart     # sections.index.json ⇄ SectionManager
│   │   └── project_configurations.dart # Metadata model + blocks
│   ├── compiler/                   # Layout/editor → AST parsers (layout_compiler,
│   │                               #   section/title/newpage builders, content_parser)
│   ├── ast/                        # AST content model (Paragraph, ListItem, Image,
│   │                               #   Table, Divider, Column, Columns, DocumentPage, …)
│   ├── format/                     # Format, ReplacementsValues, PageSetup
│   ├── layout/                     # Layout model + serialization (Dart = source of truth)
│   ├── reducer/                    # BinderActions (tree ops), BinderCounts, exceptions
│   ├── schema/                     # SchemaRegistry (mirror of schema-v1.yaml) + SchemaMigrator
│   ├── constants/ extensions/ rule/ utils/ exceptions/
│   └── rust/api/                   # GENERATED FRB bindings — do not hand-edit
assets/example.nov/                  # golden fixture (full real project), repo root
rust/                               # Rust engine crate
├── schema/schema-v1.yaml           # structural contract (Rust's only schema)
├── src/api/                        # manager.rs (FRB façade), io, validate, search,
│   │                               # text, snapshot, version (git), util, error
├── src/assets/example.nov/         # golden fixture copy used by cargo tests
├── docs/                           # format spec, engine design, git-versioning (reference)
rust_builder/                       # FRB build setup (rust_lib_novident_project_manager)
docs/                               # Dart-side plans + this documentation set
test/                               # Dart tests (mirrors lib/, + ast/, compiler/, golden/, schema/)
```

## Documentation map

| Document | Audience / purpose |
|---|---|
| `README.md` | First stop: what it is, quickstart, demo |
| `AGENTS.md` (this) | Working rules & repository map |
| `ARCHITECT.md` | How the whole system fits together (Dart + Rust) |
| `docs/index.md` | Index of the `docs/` library |
| `docs/getting-started.md` | Setup, codegen, build, run tests |
| `docs/models.md` | Reference of every schema class / codec |
| `docs/stores-and-reducer.md` | Reference of stores, I/O interfaces, reducer ops |
| `docs/engine.md` | Explanation: how the Rust engine works + JSON boundary |
| `docs/project-format.md` | Explanation/reference: the `.nov` format |
| `docs/parsers-to-ast.md` | Reference: Layout/editor to AST parsers (usage + output formats) |
| `docs/dart-project-manager-plan.md`, `docs/dart-classes-touch-plan.md`, `docs/git-snapshots-complete-plan.md` | Working plans |
| `SECURITY.md`, `CONTRIBUTING.md` | Security + contribution process |

## Code quality (expected)

- **Zero analyzer issues**: `dart analyze lib/` clean (errors, warnings, infos).
- **Tests green**: `flutter test` and `cargo test` — run both before finishing.
- Immutable, typed value models with `const` constructors, hand-written,
  **tolerant** `fromJson`/`toJson` (defaults for missing keys), and a
  `toJsonString()`/`fromJsonString()` pair for file codecs.
- Follow the conventions of `analysis_options.yaml` (`flutter_lints`) and the
  Dart skills: modern Dart (records/switch where helpful), clear naming,
  `///` doc comments in English on every public symbol.
- Match the existing file styles before adding new ones (see `docs/models.md`).

## Non-negotiables (never break)

1. **English only** in every generated or modified file, comment, message.
2. **Dart owns the schema.** Rust never parses or re-serializes schema files it
   does not own; it returns/accepts raw JSON (verbatim primitives + semantic
   read/write methods). Rust retains only `rust/schema/schema-v1.yaml` for
   structural validation. Bump it only on a format version change.
3. **One FRB importer.** `lib/src/engine/engine_client.dart` is the *only* file
   that imports `package:novident_project_manager/src/rust/...`. Domain code
   talks to `EngineClient`, never to the raw binding.
4. **Generated files are generated.** `rust/src/frb_generated.rs` and
   `lib/src/rust/**` are outputs of `flutter_rust_bridge_codegen generate`.
   Never hand-edit them.
5. **JSON keys are snake_case; Dart fields are camelCase**, mapped in codecs (e.g. `characters_no_spaces` field `charactersNoSpaces`).
6. **Schema versioning.** Opening a file migrates it up
   (`SchemaMigrator`); a file newer than the app is **never** opened/written
   (`SchemaTooNewException`).
7. **Never touch `NodeContainer.children` to mutate.** Use the container API
   (`add`, `insert`, `update`, `updateAt`, `removeAt`, `removeWhere`, `moveTo`,
   `clear`). `children` is read-only by contract.
8. **Read node state through interfaces**, not concrete types
   (`UniversalName.objectName`, `AttachableSection.section`,
   `Trashable.trashStatus`).
9. **Naming taxonomy**: `Binder*` for anything that reads/mutates the binder
   tree; `Node*` for granular editor/node concerns; `Project*`/`Session*`/
   `Target*`/`Content*` for their domains. No generic `TreeX`/`FooService`
   names.
10. **Deletion goes through the container** (`removeAt`/`remove`) so node
    listeners get notified; `unlink` only where notifications are irrelevant.
11. **Flags gate expensive work**: the full recount on session close runs only
    when `editor_preferences.compute_count_on_close_session` is true.
    `recomputeStatistics()` is **never** gated.
12. **Golden fixture is a contract.** `assets/example.nov` (repo root) must stay
    canonical. New/changed codecs must keep `test/golden/example_nov_golden_test.dart`
    green (strict verbatim for canonical owners; idempotent for derived files).
13. **No Python.** Never use `python` in scripts/commands/tests for this repo.
14. **Do not add dependencies** without a written reason and the owner's
    approval (editor packages are consumed from pub.dev as `^1.0.x`, not path).
15. **Keep the façade thin**: new engine capabilities = Rust internal module →
    thin `manager.rs` JSON façade → FRB regen → typed `EngineClient` method.
    No business logic in `manager.rs`.

## Commands

```bash
# Dart
flutter pub get
dart analyze lib/
flutter test                          # whole suite (incl. ast/, compiler/ etc)
flutter test test/compiler/content_parser_test.dart

# Rust (from repo root; crate under rust/)
cargo test --manifest-path rust/Cargo.toml

# FRB — after changing rust/src/api/manager.rs (rust_input = crate::api::manager)
flutter_rust_bridge_codegen generate

# Formatting
dart format lib test
```

## Definition of done

1. Analyzer clean + full Dart/Rust suites green.
2. Every new public symbol documented (`///`, English) and covered by a test
   (pure logic) or an integration/golden check (engine-backed).
3. No import of the raw FRB binding outside `engine_client.dart`.
4. Golden fixture unchanged unless its change is intentional and keeps
   `example_nov_golden_test.dart` green.
