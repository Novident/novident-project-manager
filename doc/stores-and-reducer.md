# Stores & reducer — reference

How persistence and tree mutations are organized.

## Store pattern

Every store = **I/O interface** (what the engine can do) + **adapter**
(`Engine*Io`, the only place that maps to `EngineClient`) + **stateful host**
(policy: lazy load, cache, persistence).

| Host | I/O interface | Adapter | Backing files | Policy |
|---|---|---|---|---|
| `DocumentCache` | `DocumentIo` | `EngineDocumentIo` | `files/<id>/content.json` | Lazy LRU (cap 50), **debounced** writes (`saveDelay`, shared), `flush`/`flushAll` |
| `BinderStore` | `BinderIo` | `EngineBinderIo` | `indexation/binder.index.json` | Decode once, keep header (version/timestamps), `persist()` recomputes `lookup` + bumps `updated_at` |
| `FormatStore` | `CompilerIo` | `EngineCompilerIo` | `compiler/formats/<id>.json` + `layouts/<id>.json` | Lazy host, no eviction; layouts resolved **before** formats by id |
| `CollectionStore<T>` | `CollectionIo` | `EngineExportsIo`, `EngineSessionsIo` | `compiler/exports/`, `history/` | Generic lazy host; save/load/delete/clear |

Wiring: `ProjectManager` constructs every store over its engine adapters.

## Reducer (binder tree operations)

`lib/src/reducer/`:

| File | Contents |
|---|---|
| `binder_actions.dart` | `BinderActions`: find/require nodes, trash folder lookup, `createDocument/Folder`, `renameNode`, `setNodeSection`, `moveNode` (cycle guard), `trashNode`, `restoreNode`, `purgeNode` (returns `files/<id>/` dirs) |
| `binder_counts.dart` | `BinderCounts.compute` (`NodeCounts`) and `.computeWords` (`WordCounts`) by tree region (trash wins; manuscript/research/normal) |
| `reducer_exceptions.dart` | `NodeNotFound`, `InvalidParent`, `InvalidMove`, `NodeType` |

Rules enforced here (see AGENTS non-negotiables):
- mutate **only** through the `NodeContainer` API (`add`/`updateAt`/`removeAt`/
  `Node.moveTo`); never `children[…] = …`.
- read name/section/trash through `UniversalName`/`AttachableSection`/`Trashable`
  mixins — no concrete-type branches in business logic.
- deletion by convention is `removeAt`/`remove` (notifications); `unlink` only
  when notifications are irrelevant.
- `trashNode` applies the trashing feature **while the node still has an owner**
  (a folder loses its owner inside `Node.moveTo`, and `Folder.setTrashState`
  refuses to act on owner-less nodes) and then moves the trashed copy.

## `ProjectManager` façade

Lifecycle (`open`, `create`, `dispose` → flushes caches) plus convenience
groups, each delegating to stores/actions/codecs and the engine:

- **Binder actions**: `createDocument`, `createFolder`, `renameNode`,
  `moveNode`, `trashNode`, `restoreNode`, `purgeNode` (also deletes document
  dirs via `engine.deleteNodeFiles`).
- **Node content**: `nodeContent`/`setNodeContent`, `nodeSynopsis`/
  `setNodeSynopsis`, `nodeNotes`/`setNodeNotes`, `nodeComments`/
  `setNodeComments`.
- **Metadata**: `readMetadata` (migrating), block updates
  (`updateProject/Author/Book/CompileDefaults/EditorPreferences/SessionState`),
  `recomputeStatistics({wordsByNodeId})` (never gated).
- **Sessions/history** (`project/session/`): `SessionHistory` (open/continue,
  no duplicate per day), `closeWritingSession` (full recount only when
  `editor_preferences.compute_count_on_close_session`; targets read from
  `target.index.json`), `adjustOpenSession` (external incremental
  `CountAdjustment`), `diffSessions`, `buildSessionSummary`.
- **Targets**: `readTargetIndex`/`writeTargetIndex`,
  `updateGeneralTarget`, `setNodeTarget`/`removeNodeTarget` (node existence
  guard), `resolveTargets` → `TargetResolver` (`targetOf`,
  `targetsWithinFolder`).
- **Snapshots**: `saveProjectSnapshot` (metadata version bump), `listSnapshots`,
  `restoreSnapshot`; `deleteSnapshot` once the engine exposes it.

## Writing sessions — decision flow

```
closeWritingSession(day)
 ├─ SessionHistory.openSession(day)      # continue if today exists
 ├─ compute_count_on_close_session?
 │    ├─ true  → measure all documents (DocumentCache + text_count),
 │    │          originals = previous session, targets = target.index,
 │    │          build summary, persist (never double-close)
 │    └─ false → nothing (external service adjusts via adjustOpenSession)
 └─ recomputeStatistics()                # always runs (never gated)
```
