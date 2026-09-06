# Novident Project Manager

The Dart package that **owns the `.nov` schema** and drives a **Rust engine** for
writing projects: binder tree, rich-text content, layouts/formats, writing
sessions, targets, snapshots and git.

> [!WARNING]
> Placeholders like `<$custom:<metadata_field>>` or `<$include:<file>>` is not available yet.

```
Dart (schema owner)  ⇄  JSON boundary  ⇄  Rust engine (I/O, git, search, diff, snapshots, validation)
```

- **Dart** owns the schema: typed models, tolerant codecs, stores, schema
  registry + migration, the binder reducer and the Layout/editor → AST parsers.
- **Rust** is schema-agnostic: verbatim file I/O, structural validation (via
  `schema-v1.yaml`), search, text diff, git and snapshots.
- `EngineClient` is the only importer of the generated FRB bindings.

> [!IMPORTANT]
> By now the **Backup**s feature is still being implemented. **Snapshots** are the safe alternative to work with.

---

## Table of contents

### Understand the project

- [ARCHITECT.md](ARCHITECT.md) — end-to-end architecture (Dart ⇄ Rust, boundary, testing).
- [doc/engine.md](doc/engine.md) — the Rust engine: modules, JSON boundary, how to extend.
- [doc/project-format.md](doc/project-format.md) — the `.nov` format, file by file.
- [doc/getting-started.md](doc/getting-started.md) — setup, codegen, build, run tests.

### Use the API

- [doc/stores-and-reducer.md](doc/stores-and-reducer.md) — stores/I/O interfaces and reducer ops.
- [doc/models.md](doc/models.md) — every schema class and codec.
- [doc/parsers-to-ast.md](doc/parsers-to-ast.md) — Layout/editor → AST parsers (usage + output formats).
- [doc/placeholders.md](doc/placeholders.md) — the `<$…>` placeholder tokens.

---

## What you can do with `ProjectManager`

`ProjectManager` (see [lib/src/project_manager.dart](lib/src/project_manager.dart))
is the single entry point. Everything is lazy and typed; operations persist only
the affected files.

### Lifecycle & stores

| Area | Getter / methods | What it gives you |
|---|---|---|
| Engine | `engine` | Low-level typed access (search, git, snapshots, validation, raw I/O) |
| Binder | `binder` | The `Folder` tree + header; load/persist, lookup & external files |
| Content | `documents` | Per-node editor content: lazy LRU cache, debounced writes |
| Compiler | `formats` | Formats and their layouts (resolved by id, lazily) |
| Exports | `exports` | Records of performed exports |
| Sessions | `sessions` | Day-by-day writing-session history |

### Binder (tree) operations

`createDocument`, `createFolder`, `renameNode`, `moveNode`, `trashNode`,
`restoreNode`, `purgeNode` (deletes document dirs too). Mutations go through
`BinderActions` with cycle guards and trash semantics, then persist the binder
(recomputing the lookup).

```dart
final doc = await manager.createDocument('draft-id', 'New chapter');
await manager.renameNode(doc.id, 'The Final Chapter');
await manager.moveNode(doc.id, 'trash-folder-id');   // → Trash
```

### Node content

`nodeContent`/`setNodeContent` (editor `Document`), `nodeSynopsis`/
`setNodeSynopsis`, `nodeNotes`/`setNodeNotes`, `nodeComments`/`setNodeComments`.

### Metadata & statistics

`readMetadata` migrates old schema versions automatically. Update blocks with
`updateProject`, `updateAuthor`, `updateBook`, `updateCompileDefaults`,
`updateEditorPreferences`, `updateSessionState`; recompute region word counts
with `recomputeStatistics({wordsByNodeId})` (never gated).

### Writing sessions (history)

Open or continue today's session without duplicates (`SessionHistory`), adjust
counts incrementally from an external counter service, and close with a full
recount gated by `compute_count_on_close_session`:

```dart
await manager.adjustOpenSession(
  DateTime.now().toUtc(),
  author: 'Elena',
  adjustment: const CountAdjustment(words: 12, characters: 64),
);
await manager.closeWritingSession(DateTime.now().toUtc(), author: 'Elena');
```

See [doc/stores-and-reducer.md](doc/stores-and-reducer.md) for the session
decision flow, and [doc/placeholders.md](doc/placeholders.md) for tokens the
compiler understands.

### Targets

Per-node and global writing targets (`target.index.json`):

```dart
final targets = await manager.resolveTargets();
final goal = targets.targetOf('chapter-1');          // override or inherited
final inFolder = targets.targetsWithinFolder('part-1');

await manager.updateGeneralTarget(const TargetGeneral(target: 50000));
await manager.setNodeTarget('chapter-1', const TargetFile(words: 5000, characters: 27000));
await manager.removeNodeTarget('chapter-1');
```

### Snapshots & git

Snapshot with a metadata version bump (`saveProjectSnapshot`), list, restore and
delete; plus full git: branches, fetch, conflicts, content/commit diffs and
remotes:

```dart
final snapshot = await manager.saveProjectSnapshot();
await manager.deleteSnapshot(snapshot.id);

await manager.gitInit();
await manager.gitBranchCreate('revision-2');
await manager.gitBranchSwitch('revision-2');
final conflicts = await manager.gitConflictDetect();
await manager.gitSetRemote('origin', 'https://example.com/repo.git');
print(await manager.gitRemotes());
```

### Search

Quick (`search`), structural/full (`searchFull`) and index maintenance
(`reindexSearch`, `searchStatus`).

---

## Example (end to end)

```dart
import 'package:novident_project_manager/novident_project_manager.dart';

Future<void> main() async {
  // Create a project (skeleton + .gitignore + git init).
  final manager = await ProjectManager.create('/path/to/my-book.nov', name: 'My Book');

  // Build a bit of binder structure.
  final root = (await manager.binder.load()).root;
  final draft = await manager.createFolder(root.id, 'Draft', folderType: FolderType.manuscript);
  final chapter = await manager.createDocument(draft.id, 'Chapter 1', section: 'chapter');

  // Set rich-text content (an editor Document).
  // await manager.setNodeContent(chapter.id, editorDocument);

  // Track a writing day and targets.
  final targets = await manager.resolveTargets();
  print('target words: ${targets.targetOf(chapter.id)?.words}');
  await manager.closeWritingSession(DateTime.now().toUtc(), author: 'Elena');

  // Version it.
  await manager.gitCommit('Chapter 1 draft', authorName: 'Elena', authorEmail: 'elena@novident.dev');
  await manager.saveProjectSnapshot();

  await manager.dispose();
}
```

> `ProjectManager`/`EngineClient` need the compiled native library, so this demo
> runs inside the app — not under `flutter test`. Pure logic (codecs, reducer,
> session math, parsers) is fully unit-tested.

## How a `.nov` project looks

A `.nov` **project is a directory** (optionally zipped for transport) with a
git repository inside:

See [doc/project-format.md](doc/project-format.md) for details:

```
files/
  metadata.json              # identity, author, book, preferences, session state, statistics
  backup.json                # compact tree mirror + checksum (generated)
  external/                  # attached files <id>.<ext>
  <node-uuid>/               # per node
    content.json             # rich text: {"document": …} (editor Document)
    synopsis.json            # same content inside an envelope
    comments.json            # { "<id>[-<username>]": { path, date, content } }
    notes.txt                # plain text
indexation/
  binder.index.json          # tree + lookup + external_files (source of truth of hierarchy)
  sections.index.json        # sections + depth outline
  icon.index.json            # icon rules (defaults + per-node overrides)
  corkboard.index.json       # corkboard visual state
  target.index.json          # writing targets (general + per-node)
  search.index.json          # engine-managed full-text index (read-only for Dart)
layouts/l<uuid>.json         # per-section presentation (Dart = source of truth)
compiler/formats/f<uuid>.json # format = layout ids + replacements + page_setup
compiler/exports/e<uuid>.json # export records (output_type, config, format_id)
history/<yyyy-MM-dd>.json     # one writing session per day
snapshots/                    # engine snapshots: <stamp>-v<version>.zip (stamp = UTC YYYY-MM-DD_HH-MM-SS)
.gitignore  .git/
```
