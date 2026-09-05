# Getting started

A tutorial for developers working on `novident_project_manager`.

## Prerequisites

- Flutter SDK (stable) and a recent Rust toolchain (`rustup`, `cargo`).
- `flutter_rust_bridge_codegen` (`dart pub global activate flutter_rust_bridge`).
- The editor packages are resolved from **pub.dev** (`^1.0.x`); never switch
  them to path dependencies.

## 1. Get dependencies and check the baseline

```bash
flutter pub get
dart analyze lib/          # must be clean (errors, warnings, infos)
flutter test               # whole Dart suite (whole Dart suite)
cargo test --manifest-path rust/Cargo.toml
```

## 2. Understand the layout

- `lib/src/engine/` — FRB wrapper (`EngineClient`) + typed DTOs. The only place
  that may import `lib/src/rust/**`.
- `lib/src/project/` — schema models, codecs, stores and their `Engine*Io`
  adapters.
- `lib/src/reducer/` — `BinderActions` (tree ops) and `BinderCounts`.
- `lib/src/schema/` — `SchemaRegistry` + `SchemaMigrator`.
- `rust/src/api/manager.rs` — the FRB façade (one thin method per capability).
- `test/golden/example_nov_golden_test.dart` — the golden contract.

## 3. Regenerate FRB after a Rust API change

Only `rust/src/api/manager.rs` is the codegen input
(`rust_input: crate::api::manager` in `flutter_rust_bridge.yaml`).

```bash
# 1. edit rust/src/api/manager.rs (thin façade, JSON in/out)
cargo test --manifest-path rust/Cargo.toml   # compile + test first
# 2. regenerate bindings (frb_generated.rs + lib/src/rust/**)
flutter_rust_bridge_codegen generate
# 3. add a typed method on EngineClient + DTOs in engine_types.dart
dart analyze lib/
```

Never hand-edit `frb_generated.rs` or `lib/src/rust/**`.

## 4. Add or change a schema model (the usual flow)

1. Find the model/codec in `lib/src/project/…` (see `docs/models.md`).
2. Keep fields snake_case == JSON keys; hyphen keys map in the codec
   (`characters_no_spaces` → `charactersNoSpaces`).
3. `fromJson` is **tolerant** (defaults); add `toJsonString()`/`fromJsonString()`.
4. Keep the fixture canonical: if the JSON shape changes, update
   `assets/example.nov/…` **and** keep
   `test/golden/example_nov_golden_test.dart` green.
5. Cover pure logic with a unit test under `test/`.

## 5. First run / demo

`EngineClient`/`ProjectManager` need the compiled native library, so the
end-to-end demo is not covered by `flutter test`. Open a real `.nov` (the
golden fixture is a directory):

```dart
final manager = await ProjectManager.open('path/to/example.nov');
final binder = await manager.binder.load();   // decode binder.index.json
final doc = await manager.createDocument('draft-id', 'New chapter');
await manager.binder.persist();
await manager.dispose();
```

## Troubleshooting

- `flutter test` fails to load a file → stale tests or a codec mismatch; run
  `dart analyze` first and read the failing reason.
- Golden test fails after a model change → the fixture or the canonical
  encoding drifted; decide which one is canonical (Dart is the source of truth)
  and align deliberately.
- FRB regen fails → compile the Rust crate first (`cargo check`).
