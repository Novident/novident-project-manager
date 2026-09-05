# Schema models — reference

Reference of the Dart schema layer: which file maps to which model, and the
rules every model follows. Field lists are abbreviated — code is the
authoritative source; this is the map.

## Mapping table

| `.nov` file | Model(s) | Location | Codec |
|---|---|---|---|
| `files/metadata.json` | `Metadata` + `ProjectInfo`, `Author`, `Book`, `CompileDefaults`, `EditorPreferences`, `SessionState`, `Statistics` | `lib/src/project/project_configurations.dart`, `…/author/author.dart` | `fromJson`/`toJson` on each block; `Metadata.copyWith` |
| `files/backup.json` | `Backup`, `BackupTree`, `BackupFolder`, `BackupDocument`, `BackupExternal` | `lib/src/project/backup/backup.dart` | string codec; compact keys `n/t/p/c/x/a` mapped to descriptive fields |
| `files/<id>/content.json` | editor `Document` | `lib/src/project/content_codec.dart` | `ContentCodec` (`{"document":…}` verbatim) |
| `files/<id>/synopsis.json` | editor `Document` (envelope) | same | `SynopsisCodec` (`{type, metadata, content}`) |
| `files/<id>/comments.json` | `Comments`, `Comment` | `lib/src/project/comments/comments.dart` | keyed `<id>[-<username>]` |
| `files/<id>/notes.txt` | `String` | — | none (raw) |
| `indexation/binder.index.json` | `Binder` (`projectId`, `projectName`, `root` Folder) | `lib/src/project/binder_codec.dart` | `BinderCodec` (tree ↔ `novident_nodes`) |
| `indexation/sections.index.json` | `SectionManager`, `SectionTypeConfigurations` | `lib/src/project/sections_codec.dart`, `…/section/` | `SectionsCodec` |
| `indexation/icon.index.json` | `IconIndex`, `IconRule` | `lib/src/project/icon/icon.dart` | flattened overrides split in codec |
| `indexation/corkboard.index.json` | `CorkboardIndex`, `Corkboard`, `CorkboardValues`, `Freeform`, `WorldNode`, … | `lib/src/project/corkboard/corkboard.dart` | string codec |
| `indexation/target.index.json` | `TargetIndex`, `TargetGeneral`, `TargetFile` | `lib/src/project/target/target.dart` | string codec + `copyWith` mutations |
| `layouts/<id>.json` | `Layout` (+ manager/options/separators) | `lib/src/layout/` | string codec (Dart = source of truth) |
| `compiler/formats/<id>.json` | `Format`, `ReplacementsValues`, `PageSetup`, `Margins`, `HeaderFooter` | `lib/src/format/` | string codec; `layouts` are **ids** |
| `compiler/exports/<id>.json` | `Export`, `ExportConfig` | `lib/src/project/export/export.dart` | string codec |
| `history/<date>.json` | `Session`, `SessionMetadata`, `SessionFileCounters`, `SessionTotal` | `lib/src/project/session/session.dart` | string codec |

## Rules every model follows

1. **Immutable** value objects, `const` constructors, named defaults.
2. Field name **== JSON key** (snake_case). Hyphen keys (`characters_no_spaces`,
   `characters_no_spaces`) become camelCase fields mapped in the codec.
3. `fromJson` is **tolerant**: missing keys fall back to defaults; no cast
   crashes on absent fields.
4. `toJsonString()` / `fromJsonString()` pair for file codecs; nested blocks use
   `toJson()` (map) / `fromJson(map)`.
5. Canonical files **always emit keys** the format expects, even as `null`
   (e.g. `IconRule.path`, `BackupFolder.p`); keys that are conditionally absent
   in the canonical form are omitted when empty (e.g. `variations`, `x` when
   not trashed). When in doubt, the golden fixture decides.
6. Equality: hand-written `==`/`hashCode` (or `Equatable` where the codebase
   already does), `mapEquals`/`listEquals` for collections, `Object.hash…`.

## Engine-side DTOs

`lib/src/engine/engine_types.dart` holds the typed results of engine calls
(search matches, git status/log/branches/merge results, snapshot info,
validation issues). Same tolerance rules apply. The engine returns snake_case
JSON; DTO `fromJson` maps it to idiomatic Dart fields.

## Registry & migration

`SchemaRegistry` (in `lib/src/schema/registry.dart`) maps every role to its
path and string codec, mirrors `schema-v1.yaml`, and lists engine-managed files
(`search.index.json`). `SchemaMigrator` migrates raw maps up; a newer file is
rejected with `SchemaTooNewException` before any decode.
