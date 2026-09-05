import 'dart:convert';

import 'package:novident_document_format/novident_document_format.dart'
    show Document, Folder, FolderType;
import 'package:novident_editor_document/novident_editor_document.dart'
    as editor;
import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_project_manager/src/project/author/author.dart';
import 'package:novident_project_manager/src/project/binder_store.dart';
import 'package:novident_project_manager/src/project/collection_store.dart';
import 'package:novident_project_manager/src/project/comments/comments.dart';
import 'package:novident_project_manager/src/project/content/text_count.dart';
import 'package:novident_project_manager/src/project/content_codec.dart';
import 'package:novident_project_manager/src/project/document_cache.dart';
import 'package:novident_project_manager/src/project/engine_adapters.dart';
import 'package:novident_project_manager/src/project/export/export.dart';
import 'package:novident_project_manager/src/project/format_store.dart';
import 'package:novident_project_manager/src/project/project_configurations.dart';
import 'package:novident_project_manager/src/project/session/session.dart';
import 'package:novident_project_manager/src/project/session/session_adjust.dart';
import 'package:novident_project_manager/src/project/session/session_builder.dart';
import 'package:novident_project_manager/src/project/session/session_history.dart';
import 'package:novident_project_manager/src/project/target/target.dart';
import 'package:novident_project_manager/src/project/target/target_resolver.dart';
import 'package:novident_project_manager/src/reducer/binder_actions.dart';
import 'package:novident_project_manager/src/reducer/binder_counts.dart';
import 'exceptions/reducer_exceptions.dart';
import 'package:novident_project_manager/src/schema/migration/schema_migration.dart';
import 'package:novident_project_manager/src/schema/registry.dart';

import 'engine/engine_client.dart';
import 'engine/engine_types.dart';

/// The Dart `ProjectManager` — the single entry point the app uses to talk to a
/// `.nov` project.
///
/// It owns the schema (typed models, parsing, serialization) and delegates the
/// heavy engines (I/O, git, search, snapshots, diff, validation) to the Rust
/// engine via `EngineClient`.
///
/// Lifecycle + engine access live here; typed stores are exposed lazily over
/// the engine:
/// - [binder] — the binder tree (mutations through `BinderActions`, flushed
///   with `BinderStore.persist`).
/// - [documents] — per-node document content (lazy LRU, debounced writes).
/// - [formats] — compiler formats and layouts (lazy host).
///
/// Top-level schema files (metadata, indexes) are read through the schema
/// registry (migrating old versions) and written back as full typed models.
class ProjectManager {
  ProjectManager._(this._engine)
      : _binderStore = BinderStore(io: EngineBinderIo(_engine)),
        _documents = DocumentCache(io: EngineDocumentIo(_engine)),
        _formats = FormatStore(io: EngineCompilerIo(_engine)),
        _exports = CollectionStore<Export>(
          io: EngineExportsIo(_engine),
          decode: Export.fromJsonString,
          encode: (Export value) => value.toJsonString(),
        ),
        _sessions = CollectionStore<Session>(
          io: EngineSessionsIo(_engine),
          decode: Session.fromJsonString,
          encode: (Session value) => value.toJsonString(),
        );

  final EngineClient _engine;

  final BinderStore _binderStore;
  final DocumentCache _documents;
  final FormatStore _formats;
  final CollectionStore<Export> _exports;
  final CollectionStore<Session> _sessions;
  Metadata? _metadata;

  /// Low-level engine access (I/O, git, search, snapshots, diff, validation).
  EngineClient get engine => _engine;

  /// The project binder: decoded `Folder` tree + header, persisted on demand.
  BinderStore get binder => _binderStore;

  /// Per-node document content (lazy LRU cache, debounced writes).
  DocumentCache get documents => _documents;

  /// Compiler formats and their layouts (lazy host).
  FormatStore get formats => _formats;

  /// Compiler exports collection (`compiler/exports/<id>.json`).
  CollectionStore<Export> get exports => _exports;

  /// Writing-session history collection (`history/<date>.json`).
  CollectionStore<Session> get sessions => _sessions;

  /// Opens an existing `.nov` project.
  static Future<ProjectManager> open(String path) async {
    final engine = EngineClient.open(path);
    return ProjectManager._(engine);
  }

  /// Creates a new `.nov` project (skeleton + `.gitignore`; initial schema
  /// files are written by the schema layer).
  static Future<ProjectManager> create(String path,
      {required String name}) async {
    EngineClient.createSkeleton(path);
    EngineClient.writeGitignore(path);
    final engine = EngineClient.open(path);
    await engine.gitInit();
    return ProjectManager._(engine);
  }

  /// Releases the underlying engine handle (and any pending cache writes).
  Future<void> dispose() async {
    await _documents.flushAll();
    _engine.close();
  }

  /// Runs a quick (document-level) search through the engine index.
  Future<List<SearchMatch>> search(
    String query, {
    SearchOptions? options,
  }) =>
      _engine.searchQuick(query, options: options);

  /// Runs the full structural search: matches are resolved to their containing
  /// block (path + block type), not just the document level.
  Future<List<StructuralMatch>> searchFull(
    String query, {
    SearchOptions? options,
  }) =>
      _engine.searchFull(query, options: options);

  /// Rebuilds the engine-owned full-text index from the current files.
  Future<SearchIndexStatus> reindexSearch() => _engine.reindexSearch();

  /// Returns the current status (dirty/stale counts) of the search index.
  Future<SearchIndexStatus> searchStatus() => _engine.searchStatus();

  /// Creates a [Document] under [parentId] and persists the binder.
  Future<Document> createDocument(
    String parentId,
    String name, {
    String? id,
    String? section,
  }) async {
    final Folder root = await _ensureBinder();
    final Document document = BinderActions.createDocument(
      root,
      parentId: parentId,
      name: name,
      id: id,
      section: section,
    );
    await _binderStore.persist();
    return document;
  }

  /// Creates a [Folder] under [parentId] and persists the binder.
  Future<Folder> createFolder(
    String parentId,
    String name, {
    String? id,
    String? section,
    FolderType folderType = FolderType.normal,
  }) async {
    final Folder root = await _ensureBinder();
    final Folder folder = BinderActions.createFolder(
      root,
      parentId: parentId,
      name: name,
      id: id,
      section: section,
      folderType: folderType,
    );
    await _binderStore.persist();
    return folder;
  }

  /// Renames a node and persists the binder.
  Future<Node> renameNode(String id, String newName) async {
    final Folder root = await _ensureBinder();
    final Node node = BinderActions.renameNode(root, id, newName);
    await _binderStore.persist();
    return node;
  }

  /// Moves a node into [targetFolderId] and persists the binder.
  Future<void> moveNode(
    String nodeId,
    String targetFolderId, {
    int? index,
  }) async {
    final Folder root = await _ensureBinder();
    BinderActions.moveNode(
      root,
      nodeId: nodeId,
      targetFolderId: targetFolderId,
      index: index,
    );
    await _binderStore.persist();
  }

  /// Moves a node into the Trash folder and persists the binder.
  Future<void> trashNode(String id) async {
    final Folder root = await _ensureBinder();
    BinderActions.trashNode(root, id);
    await _binderStore.persist();
  }

  /// Restores a trashed node and persists the binder.
  Future<void> restoreNode(
    String id,
    String targetFolderId, {
    int? index,
  }) async {
    final Folder root = await _ensureBinder();
    BinderActions.restoreNode(
      root,
      id: id,
      targetFolderId: targetFolderId,
      index: index,
    );
    await _binderStore.persist();
  }

  /// Permanently removes a node from the binder and deletes its document
  /// directories on disk.
  Future<void> purgeNode(String id) async {
    final Folder root = await _ensureBinder();
    final List<String> fileIds = BinderActions.purgeNode(root, id);
    for (final String fileId in fileIds) {
      await _engine.deleteNodeFiles(fileId);
    }
    await _binderStore.persist();
  }

  /// Loads a document's editor content (via the document cache).
  Future<editor.Document> nodeContent(String nodeId) => _documents.load(nodeId);

  /// Sets a document's editor content and flushes it immediately.
  Future<void> setNodeContent(String nodeId, editor.Document document) async {
    _documents.save(nodeId, document);
    await _documents.flush(nodeId);
  }

  /// Loads a node's synopsis, or `null` when none is stored.
  Future<editor.Document?> nodeSynopsis(String nodeId) async {
    final String? raw = await _engine.readNodeSynopsis(nodeId);
    return raw == null ? null : SynopsisCodec.decode(raw);
  }

  /// Stores a node's synopsis (wrapped in the `synopsis.json` envelope).
  Future<void> setNodeSynopsis(String nodeId, editor.Document synopsis) =>
      _engine.writeNodeSynopsis(nodeId, SynopsisCodec.encode(synopsis));

  /// Loads a node's plain-text notes, or `null` when none is stored.
  Future<String?> nodeNotes(String nodeId) => _engine.readNodeNotes(nodeId);

  /// Stores a node's plain-text notes.
  Future<void> setNodeNotes(String nodeId, String text) =>
      _engine.writeNodeNotes(nodeId, text);

  /// Loads a node's comments, or `null` when none are stored.
  Future<Comments?> nodeComments(String nodeId) async {
    final String? raw = await _engine.readNodeComments(nodeId);
    return raw == null ? null : Comments.fromJsonString(raw);
  }

  /// Stores a node's comments.
  Future<void> setNodeComments(String nodeId, Comments comments) =>
      _engine.writeNodeComments(nodeId, comments.toJsonString());

  /// Reads `files/metadata.json` (migrating older schema versions), caching it.
  Future<Metadata> readMetadata({bool refresh = false}) async {
    final Metadata? cached = _metadata;
    if (!refresh && cached != null) return cached;

    final String? raw = await _engine.readMetadata();
    if (raw == null) throw StateError('metadata not found');

    final Map<String, dynamic> migrated = SchemaMigrator.current().migrateMap(
      jsonDecode(raw) as Map<String, dynamic>,
      role: 'metadata',
    );
    final Metadata metadata =
        SchemaRegistry.metadata.decode(jsonEncode(migrated));
    _metadata = metadata;
    return metadata;
  }

  /// Recomputes the project statistics from the binder tree and persists them.
  ///
  /// [wordsByNodeId] carries measured word counts (e.g. from the session
  /// close); when present the word totals are recomputed by region, otherwise
  /// the previously stored word counts are preserved.
  Future<Statistics> recomputeStatistics(
      {Map<String, int>? wordsByNodeId}) async {
    final Folder root = await _ensureBinder();
    final NodeCounts counts = BinderCounts.compute(root);

    final Metadata metadata = await readMetadata();
    final Statistics previous = metadata.statistics;
    final WordCounts? words = wordsByNodeId == null
        ? null
        : BinderCounts.computeWords(root, wordsByNodeId);
    final Statistics updated = Statistics(
      totalDocuments: counts.totalDocuments,
      totalFolders: counts.totalFolders,
      totalExternalFiles: counts.totalExternalFiles,
      totalWordCount: words?.totalWords ?? previous.totalWordCount,
      manuscriptWordCount:
          words?.manuscriptWords ?? previous.manuscriptWordCount,
      researchWordCount: words?.researchWords ?? previous.researchWordCount,
      trashWordCount: words?.trashWords ?? previous.trashWordCount,
    );
    await _updateMetadata(
      (Metadata _) => metadata.copyWithStatistics(updated),
    );
    return updated;
  }

  /// Closes the writing session of [day] — the orchestrator flow.
  ///
  /// Gating: the expensive full recount of every document only runs when
  /// editor_preferences.compute_count_on_close_session is true (the default).
  /// When false the app trusts the external counting service (see
  /// [adjustOpenSession]) and no recount happens here.
  ///
  /// Either way structural statistics are recomputed (the one thing that runs
  /// regardless of the flag), and an already-closed session is never
  /// double-closed.
  Future<Session> closeWritingSession(
    DateTime day, {
    String author = '',
    DateTime Function()? now,
  }) async {
    final SessionHistory history = SessionHistory(store: _sessions);
    final Session opened =
        await history.openSession(day, author: author, now: now);

    if (await _computeCountOnCloseSession()) {
      final Map<String, SessionNodeMeasures> current =
          await _measureAllDocuments();
      final Map<String, int> words = current
          .map((String id, SessionNodeMeasures m) => MapEntry(id, m.words));
      if (opened.metadata.total.words == 0) {
        await _closeFromMeasures(history, opened, current);
      }
      await recomputeStatistics(wordsByNodeId: words);
    } else {
      // Not gated: structural statistics always stay in sync.
      await recomputeStatistics();
    }
    return opened.metadata.total.words > 0
        ? await history.store.load(sessionDateKey(day))
        : opened;
  }

  Future<bool> _computeCountOnCloseSession() async {
    final EditorPreferences preferences =
        (await readMetadata()).editorPreferences;
    return preferences.computeCountOnCloseSession;
  }

  /// Recounts every document, builds the session totals, and persists them.
  Future<void> _closeFromMeasures(
    SessionHistory history,
    Session opened,
    Map<String, SessionNodeMeasures> current,
  ) async {
    final DateTime? day = DateTime.tryParse(opened.sessionDate);
    final Map<String, SessionFileCounters> originals = day == null
        ? <String, SessionFileCounters>{}
        : await _originalsBefore(day);
    final TargetGeneral targets = await _readTargets();

    final SessionSummary summary = buildSessionSummary(
      originals: originals,
      current: current,
      target: targets.target,
      targetCharacters: targets.targetCharacters,
      typeTarget: targets.typeTarget,
    );
    final Session closed = opened.copyWith(
      metadata: SessionMetadata(files: summary.files, total: summary.total),
    );
    await history.saveSession(closed);
  }

  /// The writing targets from `target.index.json` (zero when absent).
  Future<TargetGeneral> _readTargets() async {
    final String? raw = await _engine.readTarget();
    if (raw == null) return const TargetGeneral();
    return TargetIndex.fromJsonString(raw).general;
  }

  /// Live measures of every non-trashed document (via content cache + editor
  /// counting). Documents without content are omitted.
  Future<Map<String, SessionNodeMeasures>> _measureAllDocuments() async {
    final Folder root = await _ensureBinder();
    final List<String> ids = <String>[];
    root.visitAllNodes(shouldGetNode: (Node node) {
      if (node is Document && !BinderActions.isTrashed(node)) {
        ids.add(node.id);
      }
      return false;
    });

    final Map<String, SessionNodeMeasures> measures =
        <String, SessionNodeMeasures>{};
    for (final String id in ids) {
      final editor.Document? content = await _tryLoadContent(id);
      if (content == null) continue;
      final TextCount count = countEditorDocument(content);
      measures[id] = SessionNodeMeasures(
        words: count.words,
        characters: count.characters,
        noSpaces: count.charactersNoSpaces,
      );
    }
    return measures;
  }

  Future<editor.Document?> _tryLoadContent(String nodeId) async {
    try {
      return await _documents.load(nodeId);
    } on StateError {
      return null; // document without content yet
    }
  }

  /// End counters of the most recent session strictly before [day].
  Future<Map<String, SessionFileCounters>> _originalsBefore(
      DateTime day) async {
    final List<String> dates = await _sessions.listKeys();
    final String key = sessionDateKey(day);
    dates.sort();
    final List<String> previous =
        dates.where((String d) => d.compareTo(key) < 0).toList();
    if (previous.isEmpty) return <String, SessionFileCounters>{};
    return (await _sessions.load(previous.last)).metadata.files;
  }

  /// Applies an incremental [CountAdjustment] to the open session of [day].
  ///
  /// For external counting services: they report only the deltas of a change
  /// batch (no full recount), this updates totals — and [nodeId]'s file counters
  /// when the node is known — then persists.
  Future<Session> adjustOpenSession(
    DateTime day, {
    String author = '',
    String? nodeId,
    required CountAdjustment adjustment,
  }) async {
    final SessionHistory history = SessionHistory(store: _sessions);
    final Session opened = await history.openSession(day, author: author);
    final Session adjusted =
        adjustSession(opened, nodeId: nodeId, adjustment: adjustment);
    await history.saveSession(adjusted);
    return adjusted;
  }

  /// Reads `target.index.json` (empty index when the file is absent).
  Future<TargetIndex> readTargetIndex() async {
    final String? raw = await _engine.readTarget();
    if (raw == null) return const TargetIndex();
    return TargetIndex.fromJsonString(raw);
  }

  /// Resolves per-node targets against the current binder and `target.index`.
  Future<TargetResolver> resolveTargets() async {
    return TargetResolver(
        index: await readTargetIndex(), root: await _ensureBinder());
  }

  /// Persists [index] to `target.index.json`.
  Future<void> writeTargetIndex(TargetIndex index) async {
    final TargetIndex ready = index.schemaVersion == null
        ? index.copyWith(schemaVersion: kCurrentSchemaVersion)
        : index;
    await _engine.writeTarget(jsonEncode(ready.toJson()));
  }

  /// Replaces the project-wide writing goal.
  Future<void> updateGeneralTarget(TargetGeneral general) async {
    await writeTargetIndex((await readTargetIndex()).updateGeneral(general));
  }

  /// Sets (adds or replaces) the per-node target of an existing node.
  Future<void> setNodeTarget(String nodeId, TargetFile target) async {
    await _assertNodeExists(nodeId);
    await writeTargetIndex(
        (await readTargetIndex()).setOverride(nodeId, target));
  }

  /// Removes the per-node target of an existing node (no-op when unset).
  Future<void> removeNodeTarget(String nodeId) async {
    await _assertNodeExists(nodeId);
    final TargetIndex index = await readTargetIndex();
    if (!index.files.containsKey(nodeId)) return;
    await writeTargetIndex(index.removeOverride(nodeId));
  }

  Future<void> _assertNodeExists(String nodeId) async {
    if (BinderActions.findNode(await _ensureBinder(), nodeId) == null) {
      throw NodeNotFoundException(nodeId);
    }
  }

  /// Bumps the project version (metadata) and stores a snapshot under it.
  ///
  /// The snapshot file is named by the engine from the version (`snapshots/`),
  /// matching `example.nov`'s `date-v<semver>.zip` convention.
  Future<SnapshotInfo> saveProjectSnapshot() async {
    final Metadata metadata = await readMetadata();
    final int next = metadata.project.version + 1;
    await updateProject(metadata.project.copyWith(
      version: next,
      updatedAt: DateTime.now().toIso8601String(),
    ));
    return _engine.snapshotCreate(version: next);
  }

  /// Restores a stored snapshot over the project (overwrites files).
  Future<void> deleteSnapshot(String snapshotId) =>
      _engine.snapshotDelete(snapshotId);

  /// Lists stored snapshots, newest first.
  Future<List<SnapshotInfo>> listSnapshots() => _engine.snapshotList();

  /// Restores a stored snapshot over the project (overwrites files).
  Future<void> restoreSnapshot(String snapshotId) =>
      _engine.snapshotRestore(snapshotId);

  /// Updates the project info block.
  Future<void> updateProject(ProjectInfo project) =>
      _updateMetadata((Metadata m) => m.copyWith(project: project));

  /// Updates the author block.
  Future<void> updateAuthor(Author author) =>
      _updateMetadata((Metadata m) => m.copyWith(author: author));

  /// Updates the book block.
  Future<void> updateBook(Book book) =>
      _updateMetadata((Metadata m) => m.copyWith(book: book));

  /// Updates the compile defaults block.
  Future<void> updateCompileDefaults(CompileDefaults compileDefaults) =>
      _updateMetadata(
          (Metadata m) => m.copyWith(compileDefaults: compileDefaults));

  /// Updates the editor preferences block.
  Future<void> updateEditorPreferences(EditorPreferences preferences) =>
      _updateMetadata(
          (Metadata m) => m.copyWith(editorPreferences: preferences));

  /// Updates the session state block.
  Future<void> updateSessionState(SessionState session) =>
      _updateMetadata((Metadata m) => m.copyWith(session: session));

  Future<void> _updateMetadata(Metadata Function(Metadata) mutate) async {
    final Metadata updated = mutate(await readMetadata());
    _metadata = updated;
    await _engine.writeMetadata(jsonEncode(updated.toJson()));
  }

  /// Loads the binder (from disk or cache) and returns its root folder.
  Future<Folder> _ensureBinder() async {
    final BinderStore store = _binderStore;
    return store.isLoaded ? store.root : (await store.load()).root;
  }

  /// Creates a branch from the current HEAD.
  Future<void> gitBranchCreate(String name) => _engine.gitBranchCreate(name);

  /// Creates a branch from a specific commit [oid].
  Future<void> gitBranchCreateFromCommit(String name, String oid) =>
      _engine.gitBranchCreateFromCommit(name, oid);

  /// Switches to the branch named [name].
  Future<void> gitBranchSwitch(String name) => _engine.gitBranchSwitch(name);

  /// Merges the branch named [name] into the current branch.
  Future<GitMergeResult> gitBranchMerge(String name) =>
      _engine.gitBranchMerge(name);

  /// Deletes the branch named [name]; [force] drops unmerged branches.
  Future<void> gitBranchDelete(String name, {required bool force}) =>
      _engine.gitBranchDelete(name, force: force);

  /// Returns the current branch name.
  Future<String> gitCurrentBranch() => _engine.gitCurrentBranch();

  /// Stages and commits all changes with [message] and the given identity.
  ///
  /// Returns the commit oid (sha).
  Future<String> gitCommit(
    String message, {
    required String authorName,
    required String authorEmail,
  }) =>
      _engine.gitCommit(message,
          authorName: authorName, authorEmail: authorEmail);

  /// Fetches from the remote (default `origin`).
  Future<void> gitFetch(
    String remoteName, {
    GitCredentials? credentials,
  }) =>
      _engine.gitFetch(
        remoteName,
        credentials: credentials,
      );

  /// Detects every merge conflict in the repository.
  Future<List<GitConflictInfo>> gitConflictDetect() =>
      _engine.gitConflictDetect();

  /// Resolves every conflicted file with the same [resolution].
  Future<void> gitConflictResolveAll(ConflictResolution resolution) async =>
      _engine.gitConflictResolveAll(resolution);

  /// Finishes the conflict resolution (clears the conflict state).
  Future<void> gitConflictFinish() => _engine.gitConflictFinish();

  /// Structural diff between two JSON-serialized document trees, or `null`
  /// when the payloads are not readable as documents.
  Future<GitTreeDiff?> gitDiffJsonDocuments(
    String oldJson,
    String newJson,
  ) =>
      _engine.gitDiffJsonDocuments(oldJson, newJson);

  /// Structural diff between two document nodes by uuid, or `null`.
  Future<GitTreeDiff?> gitDiffDocuments(String oldUuid, String newUuid) =>
      _engine.gitDiffDocuments(oldUuid, newUuid);

  /// Diff introduced by the last commit of [branch], or `null`.
  Future<GitCommitDiff?> gitLastCommitDiff(String branch) =>
      _engine.gitLastCommitDiff(branch);

  /// Diff between two commits, or `null`.
  Future<GitCommitDiff?> gitDiffBetweenCommits(String oldOid, String newOid) =>
      _engine.gitDiffBetweenCommits(oldOid, newOid);

  /// Initializes the internal git repository (no-op when already present).
  Future<void> gitInit() => _engine.gitInit();

  /// Sets (adds or replaces) the URL of the remote named [name].
  Future<void> gitSetRemote(String name, String url) =>
      _engine.gitSetRemote(name, url);

  /// Returns the URL of the remote named [name], or `null` when not configured.
  Future<String?> gitRemoteUrl(String name) => _engine.gitRemoteUrl(name);

  /// Lists the configured remotes with their URLs.
  Future<List<GitRemoteInfo>> gitRemotes() => _engine.gitRemotes();
}
