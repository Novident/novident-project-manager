# Changelog

All notable changes to the `rust_lib_novident_project_manager` native plugin.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-09-04

First publishable version of the native engine plugin.

### Added
- `flutter_rust_bridge` (v2) native plugin using **cargokit** — compiles the
  `novident_project_manager` Rust crate on the consumer's machine for Android,
  iOS, Linux, macOS and Windows (`ffiPlugin` on every platform).
- Exposes the engine façade from `rust/src/api/manager.rs` (verbatim file I/O,
  structural validation against `schema-v1.yaml`, full-text search, delta
  diff, git operations and snapshots) to Dart through FRB.

### Notes
- Consumed by the `novident_project_manager` Dart package (hosted constraint);
  local development uses a path override (`pubspec_overrides.yaml`).
- Generated files (`frb_generated.rs`, `lib/src/rust/**`) are outputs of
  `flutter_rust_bridge_codegen generate` — do not hand-edit.
