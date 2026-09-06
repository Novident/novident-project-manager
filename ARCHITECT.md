# ARCHITECT.md — Novident Project Manager Architecture

## System in one paragraph

A `.nov` project is a directory of JSON schema files (metadata, indexes,
layouts, formats, per-node content) plus git metadata and snapshots. This
package splits responsibility in two: **Dart owns the schema** (typed models,
codecs, serialization, the reducer) and **Rust is the engine** (filesystem I/O,
git, full-text search, snapshots, validation, text diff). They talk only
through a **JSON string boundary** exposed by `flutter_rust_bridge`; Dart is
the only layer that parses and writes schema files.

```
                    ┌─────────────────────────────────────────────┐
   app / editor     │  ProjectManager (façade)                    │
                    │    ├─ BinderStore / DocumentCache /         │
                    │    │   FormatStore / CollectionStore        │
                    │    ├─ SchemaRegistry + SchemaMigrator       │
                    │    └─ BinderActions / BinderCounts          │
                    └──────────────┬──────────────────────────────┘
                                   │ JSON strings (raw schema, git, search, …)
                    ┌──────────────▼──────────────────────────────┐
                    │  EngineClient (typed wrapper)               │
                    │    └─ FRB binding  (lib/src/rust/**)        │
                    └──────────────┬──────────────────────────────┘
                                   │ FFI (auto-generated)
                    ┌──────────────▼──────────────────────────────┐
                    │  Rust engine (manager.rs façade)            │
                    │    io · validate · search · text ·          │
                    │    snapshot · version(git)                  │
                    └─────────────────────────────────────────────┘
                                    │
                        filesystem (.nov directory)
```

## The two halves

### Rust engine (`rust/`)

* **Schema-agnostic by design.** Rust does not know Dart's models. It holds one
  piece of schema only (current): `rust/schema/schema-v1.yaml` (required dirs/files,
  collections, integrity checks, id conventions) used by `validate/contract.rs`.
* **Owns the machine work**: verbatim file I/O (`io/`), structural validation
  (`validate/`), full-text search (`search.rs`), text/delta diff (`text/`),
  snapshots (`snapshot.rs`), git (`version/`).
* **Façade**: every capability is a thin method on `manager.rs` returning
  `Result<String, ProjectError>` (serde JSON) or a raw string; structured
  inputs arrive as `*_json` arguments. No business logic lives in `manager.rs`.
* **Extending Rust**: add a capability in the right module → expose a thin
  façade method → `flutter_rust_bridge_codegen generate` → add a typed method
  on `EngineClient`. The full git/snapshot surface is implemented internally
  (`version/{branch,conflict,content_diff,credentials,repo_manager}.rs`); see

### Dart schema layer (`lib/`)

* **`EngineClient` is the single FRB importer** (`lib/src/engine/engine_client.dart`).
  It exposes typed methods/DTOs (`engine_types.dart`) for engine results and
  raw-JSON methods for schema files.
* **Stores follow one pattern**: an I/O interface (`DocumentIo`, `BinderIo`,
  `CompilerIo`, `CollectionIo`) + an `Engine*Io` adapter + a stateful host
  (`DocumentCache`, `BinderStore`, `FormatStore`, `CollectionStore`). Hosts load
  lazily, cache what they own, and persist on demand. `DocumentCache` is the
  only one with eviction (LRU) and debounced writes.
* **Schema files** are parsed by typed models/codecs owned by Dart:
  `project_configurations.dart` (Metadata), `binder_codec.dart`,
  `sections_codec.dart`, `project/target|icon|corkboard|session|export|backup|
  comments/*`, `format/` and `layout/`. Dart is the source of truth for
  Layout/Format serialization.
* **`SchemaRegistry`** mirrors `schema-v1.yaml` and binds each role → path →
  string codec. **`SchemaMigrator`** migrates a raw map up to the current
  version and rejects files that are newer than the app.
* **Reducer**: `BinderActions` mutates the binder tree (create/rename/move/
  trash/restore/purge) through the `NodeContainer` API; `BinderCounts` and
  `BinderCounts.computeWords` aggregate statistics; `ProjectManager` glues
  action + persist + session/statistics flows.
* **Compiler**: Layout/editor objects are converted to the **AST** model
  (`lib/src/ast/`) by `lib/src/compiler/` — `LayoutCompiler` (layout + node +
  context → `DocumentPage`), `LayoutSectionBuilder`/`TitleOptionsBuilder`/
  `NewPageOptionsBuilder`, and `ContentParser` (editor `Document` → AST blocks:
  paragraphs, nested lists, images, tables, dividers, columns). Data classes are
  pure: the conversions live outside them.
* **Conveniences on `ProjectManager`**: binder actions, per-node content
  (Document/synopsis/notes/comments), metadata updates, writing sessions
  (open/continue/close, external `CountAdjustment`, session diff),
  target reads/updates, snapshots (version bump), git passthroughs.

## Boundaries & invariants

1. **JSON is the contract.** Rust hands Dart raw JSON; Dart hands Rust raw
   JSON. Dart models never leak into Rust and vice-versa.
2. **JSON keys are snake_case; Dart fields are camelCase**, mapped in the
   codecs (boundary DTOs included).
3. **Opening always migrates up and never downgrades.**
4. **Tree mutations go through the container API**; reads go through node
   mixins/interfaces, never concrete type casts in business logic.
5. **Engine results are typed at the edge** (`engine_types.dart`), then flow as
   models into the app.

## Testing strategy

* Rust: unit tests inside modules + integration tests in `rust/tests/`
  (io/validate/search/git) over throwaway repos.
* Dart: unit tests mirror `lib/` (`test/project`, `test/reducer`,
  `test/schema`, `test/format`, `test/layout`, `test/ast`, `test/compiler`)
  with fakes for I/O interfaces;
  engine-backed paths are only statically analyzed (no native lib in `flutter test`).
* **Golden**: `test/golden/example_nov_golden_test.dart` parses the real
  `example.nov` fixture, asserts migrations are no-ops on v1 files, requires
  **verbatim** reproduction for canonical owners (metadata, sections, icon,
  corkboard, target, backup, layouts, exports, sessions) and **idempotency**
  for derived files (binder lookup, format layout ids).

## Repository layout

```
lib/
├── novident_project_manager.dart     # public barrel (EngineClient, EngineTypes, ProjectManager)
├── src/
│   ├── engine/                       # EngineClient (only FRB importer) + engine_types DTOs
│   ├── project_manager.dart          # ProjectManager façade (lifecycle, stores, reducer conveniences)
│   ├── project/                      # Dart schema layer: models, codecs, stores, adapters
│   │   ├── author/ section/ target/ synopsis/ icon/ corkboard/ session/ export/ backup/ comments/
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
│   ├── compiler/                   # Layout/editor → AST parsers
│   ├── ast/                        # AST content model (blocks, lists, tables, …)
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
| `SECURITY.md`, `CONTRIBUTING.md` | Security + contribution process |
