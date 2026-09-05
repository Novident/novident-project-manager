# The Rust engine

Explanation of the half of the system that lives in `rust/`.

## Principle: schema-agnostic engine

Rust never parses or re-serializes schema files that Dart owns. It reads and
writes those files **verbatim** (raw JSON strings) through **semantic**
entry points, and validates their *structure* against the only schema it
retains:

```
rust/schema/schema-v1.yaml
```

That YAML declares required directories/files, collection directories (with
their item key), integrity checks, and id conventions. It changes **only** on a
format version bump, never on a field addition (fields are Dart's job).

## Modules

| Module | Responsibility | Notes |
|---|---|---|
| `api/io/` | Verbatim file I/O | `read_file`/`write_file`/`delete_file`/`list_files` + semantic readers/writers (`read_metadata`, `write_binder`, `read_layout(id)`, …) |
| `api/validate/` | Structural validation | loads `schema-v1.yaml`, checks required entries + integrity rules (`binder_unique_ids`, `format_layouts_ref_existing`, …) |
| `api/search.rs` | Full-text index | quick/full search over plain-text fields; engine-owned index (`search.index.json`) |
| `api/text/` | Delta engine | `Delta` ops, attributes, content reader, op iterator, text diff (`diff_delta`) |
| `api/snapshot.rs` | Snapshots | zip snapshots in `snapshots/` (`date-v<n>.zip`); create/list/restore |
| `api/version/` | Git + versioning | `git_service`, `branch.rs`, `conflict.rs`, `content_diff.rs`, `credentials.rs`, `repo_manager.rs` (full surface; façade wiring tracked in `docs/git-snapshots-complete-plan.md`) |
| `api/manager.rs` | FRB façade | one thin `Result<String, ProjectError>` method per capability; structured input via `*_json` args; **no business logic** |
| `api/error.rs` | Errors | `ProjectError` + `ErrorCode` |

## The JSON boundary

Every façade method returns a JSON **string** (serde) or a raw file string;
structured parameters arrive as JSON strings too. The Dart side (`EngineClient`)
parses engine results into typed DTOs (`engine_types.dart`) and keeps schema
files as raw JSON for the schema layer to parse.

```
Dart model  ──toJson──►  JSON string  ──►  manager.rs (verbatim I/O)
Dart model  ◄──fromJson── JSON string  ◄──  manager.rs (serde results)
```

Consequences:

- The two halves evolve independently (add fields in Dart without touching
  Rust; add engine capabilities without touching Dart models).
- A schema file never passes through Rust transforms, so it round-trips
  byte-stable across the boundary.

## Structural validation & integrity

`validate/` reports issues as `ValidationIssue` lists (severity, path, code,
message). Missing required files are **errors**; missing optional ones are
warnings. Checks never abort opening — the app reports them.

## How to extend

1. Implement in the right module (or reuse an existing internal API).
2. Add a thin façade method on `manager.rs` that returns JSON via serde.
3. `flutter_rust_bridge_codegen generate`.
4. Add a typed method + DTOs on the Dart side (`EngineClient`).
5. Test: Rust in `rust/tests/` (real temp repos), Dart via `analyze` (native
   lib is not available in `flutter test`) and pure DTO parsing tests.
