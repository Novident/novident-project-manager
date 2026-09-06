import 'dart:convert';

import 'package:novident_project_manager/src/rust/api/manager.dart' as rust;

import 'engine_types.dart';

/// Typed wrapper over the generated FRB binding.
///
/// This is the **only** place the generated binding (`lib/src/rust/`) is
/// imported. Domain code talks to `EngineClient`/`ProjectManager`, never to the
/// raw FRB facade.
///
/// The engine returns JSON strings for structured results (search, git,
/// snapshots, validation); this wrapper parses them into the typed DTOs in
/// `engine_types.dart`. Schema files (metadata, binder, …) are returned as raw
/// JSON strings here — Dart's schema layer parses them into typed models.
class EngineClient {
  EngineClient._(this._engine);

  final rust.ProjectManager _engine;

  /// Opens an existing `.nov` project and returns its engine handle.
  static EngineClient open(String path) =>
      EngineClient._(rust.openProject(path: path));

  /// Creates the empty directory skeleton of a new `.nov` project.
  static void createSkeleton(String path) =>
      rust.createProjectSkeleton(path: path);

  /// Writes the standard internal `.gitignore` of a new project.
  static void writeGitignore(String path) => rust.writeGitignore(path: path);

  /// Closes the engine handle and releases the underlying project resources.
  void close() => _engine.close();

  /// Reads a file as raw text, relative to the project root.
  ///
  /// Returns `null` when the file does not exist.
  Future<String?> readFile(String relativePath) =>
      _engine.readFile(relativePath: relativePath);

  /// Writes raw text to a file, relative to the project root.
  Future<void> writeFile(String relativePath, String contents) =>
      _engine.writeFile(relativePath: relativePath, contents: contents);

  /// Deletes a file, relative to the project root.
  Future<void> deleteFile(String relativePath) =>
      _engine.deleteFile(relativePath: relativePath);

  /// Lists the file names (not full paths) inside [dir], relative to the root.
  Future<List<String>> listFiles(String dir) => _engine.listFiles(dir: dir);

  /// Reads `files/styles.json` as raw JSON, or `null` when missing.
  Future<String?> readStyles() => _engine.readStyles();

  /// Writes `files/styles.json` from its raw JSON string.
  Future<void> writeStyles(String json) => _engine.writeStyles(json: json);

  /// Deletes `files/styles.json` when present.
  Future<void> deleteStyle() => _engine.deleteStyle();

  /// Reads `files/metadata.json` as raw JSON, or `null` when missing.
  Future<String?> readMetadata() => _engine.readMetadata();

  /// Writes `files/metadata.json` from its raw JSON string.
  Future<void> writeMetadata(String json) => _engine.writeMetadata(json: json);

  /// Reads `files/backup.json` as raw JSON, or `null` when missing.
  Future<String?> readBackup() => _engine.readBackup();

  /// Writes `files/backup.json` from its raw JSON string.
  Future<void> writeBackup(String json) => _engine.writeBackup(json: json);

  /// Reads `indexation/binder.index.json` as raw JSON, or `null` when missing.
  Future<String?> readBinder() => _engine.readBinder();

  /// Writes `indexation/binder.index.json` from its raw JSON string.
  Future<void> writeBinder(String json) => _engine.writeBinder(json: json);

  /// Reads `indexation/sections.index.json` as raw JSON, or `null` when missing.
  Future<String?> readSections() => _engine.readSections();

  /// Writes `indexation/sections.index.json` from its raw JSON string.
  Future<void> writeSections(String json) => _engine.writeSections(json: json);

  /// Reads `indexation/icon.index.json` as raw JSON, or `null` when missing.
  Future<String?> readIcon() => _engine.readIcon();

  /// Writes `indexation/icon.index.json` from its raw JSON string.
  Future<void> writeIcon(String json) => _engine.writeIcon(json: json);

  /// Reads `indexation/corkboard.index.json` as raw JSON, or `null` when missing.
  Future<String?> readCorkboard() => _engine.readCorkboard();

  /// Writes `indexation/corkboard.index.json` from its raw JSON string.
  Future<void> writeCorkboard(String json) =>
      _engine.writeCorkboard(json: json);

  /// Reads `indexation/target.index.json` as raw JSON, or `null` when missing.
  Future<String?> readTarget() => _engine.readTarget();

  /// Writes `indexation/target.index.json` from its raw JSON string.
  Future<void> writeTarget(String json) => _engine.writeTarget(json: json);

  /// Reads the engine-owned `indexation/search.index.json`, or `null` when the
  /// index has not been built yet.
  Future<String?> readSearch() => _engine.readSearch();

  /// Lists every stored layout id in `layouts/`.
  Future<List<String>> listLayouts() => _engine.listLayouts();

  /// Reads a single layout (`layouts/<id>.json`) as raw JSON, or `null` when
  /// it does not exist.
  Future<String?> readLayout(String id) => _engine.readLayout(id: id);

  /// Writes a single layout (`layouts/<id>.json`) from its raw JSON string.
  Future<void> writeLayout(String id, String json) =>
      _engine.writeLayout(id: id, json: json);

  /// Deletes a single layout (`layouts/<id>.json`).
  Future<void> deleteLayout(String id) => _engine.deleteLayout(id: id);

  /// Lists every stored format id in `compiler/formats/`.
  Future<List<String>> listFormats() => _engine.listFormats();

  /// Reads a single format (`compiler/formats/<id>.json`) as raw JSON, or
  /// `null` when it does not exist.
  Future<String?> readFormat(String id) => _engine.readFormat(id: id);

  /// Writes a single format (`compiler/formats/<id>.json`) from raw JSON.
  Future<void> writeFormat(String id, String json) =>
      _engine.writeFormat(id: id, json: json);

  /// Deletes a single format (`compiler/formats/<id>.json`).
  Future<void> deleteFormat(String id) => _engine.deleteFormat(id: id);

  /// Lists every stored export id in `compiler/exports/`.
  Future<List<String>> listExports() => _engine.listExports();

  /// Reads a single export (`compiler/exports/<id>.json`) as raw JSON, or
  /// `null` when it does not exist.
  Future<String?> readExport(String id) => _engine.readExport(id: id);

  /// Writes a single export (`compiler/exports/<id>.json`) from raw JSON.
  Future<void> writeExport(String id, String json) =>
      _engine.writeExport(id: id, json: json);

  /// Deletes a single export (`compiler/exports/<id>.json`).
  Future<void> deleteExport(String id) => _engine.deleteExport(id: id);

  /// Lists every stored session (history) date in `history/`.
  Future<List<String>> listSessions() => _engine.listSessions();

  /// Reads a single session (`history/<date>.json`) as raw JSON, or `null`
  /// when it does not exist.
  Future<String?> readSession(String date) => _engine.readSession(date: date);

  /// Writes a single session (`history/<date>.json`) from raw JSON.
  Future<void> writeSession(String date, String json) =>
      _engine.writeSession(date: date, json: json);

  /// Deletes a single session (`history/<date>.json`).
  Future<void> deleteSession(String date) => _engine.deleteSession(date: date);

  /// Reads a node's `files/<id>/content.json` as raw JSON, or `null` when the
  /// node has no content yet.
  Future<String?> readNodeContent(String id) => _engine.readNodeContent(id: id);

  /// Writes a node's `files/<id>/content.json` from raw JSON.
  Future<void> writeNodeContent(String id, String json) =>
      _engine.writeNodeContent(id: id, json: json);

  /// Reads a node's `files/<id>/comments.json` as raw JSON, or `null` when the
  /// node has no comments.
  Future<String?> readNodeComments(String id) =>
      _engine.readNodeComments(id: id);

  /// Writes a node's `files/<id>/comments.json` from raw JSON.
  Future<void> writeNodeComments(String id, String json) =>
      _engine.writeNodeComments(id: id, json: json);

  /// Reads a node's plain-text `files/<id>/notes.txt`, or `null` when missing.
  Future<String?> readNodeNotes(String id) => _engine.readNodeNotes(id: id);

  /// Writes a node's plain-text `files/<id>/notes.txt`.
  Future<void> writeNodeNotes(String id, String text) =>
      _engine.writeNodeNotes(id: id, text: text);

  /// Reads a node's `files/<id>/synopsis.json` as raw JSON, or `null` when the
  /// node has no synopsis.
  Future<String?> readNodeSynopsis(String id) =>
      _engine.readNodeSynopsis(id: id);

  /// Writes a node's `files/<id>/synopsis.json` from raw JSON.
  Future<void> writeNodeSynopsis(String id, String json) =>
      _engine.writeNodeSynopsis(id: id, json: json);

  /// Removes the physical `files/<id>/` directory. The binder must be updated
  /// by Dart (removal through the reducer) before or after this call.
  Future<void> deleteNodeFiles(String id) => _engine.deleteNodeFiles(id: id);

  /// Runs the engine's structural validation and returns the reported issues.
  ///
  /// Missing required files are errors; missing optional ones are warnings.
  Future<List<ValidationIssue>> validate() async {
    final raw = await _engine.validate();
    return (jsonDecode(raw) as List)
        .map((e) => ValidationIssue.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Rebuilds the full-text search index from the current files and returns
  /// its status.
  Future<SearchIndexStatus> reindexSearch() async {
    final raw = await _engine.reindexSearch();
    return SearchIndexStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Runs a quick (document-level) search over the engine index.
  Future<List<SearchMatch>> searchQuick(String query,
      {SearchOptions? options}) async {
    final raw = await _engine.search(
      query: query,
      optionsJson: jsonEncode((options ?? const SearchOptions()).toJson()),
      mode: 'quick',
    );
    return (jsonDecode(raw) as List)
        .map((e) => SearchMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Runs the full structural search: every match is resolved to its
  /// containing block (path and block type), not only the document level.
  Future<List<StructuralMatch>> searchFull(String query,
      {SearchOptions? options}) async {
    final raw = await _engine.search(
      query: query,
      optionsJson: jsonEncode((options ?? const SearchOptions()).toJson()),
      mode: 'full',
    );
    return (jsonDecode(raw) as List)
        .map((e) => StructuralMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the current status (dirty/stale counts) of the search index.
  Future<SearchIndexStatus> searchStatus() async {
    final raw = await _engine.searchStatus();
    return SearchIndexStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Computes the Quill delta between two document JSON payloads and returns
  /// the operational transform (JSON) that turns [beforeJson] into [afterJson].
  Future<String> diffDelta(String beforeJson, String afterJson) =>
      _engine.diffDelta(beforeJson: beforeJson, afterJson: afterJson);

  /// Returns the git working-tree status entries of the project repository.
  Future<List<GitStatusEntry>> gitStatus() async {
    final raw = await _engine.gitStatus();
    return (jsonDecode(raw) as List)
        .map((e) => GitStatusEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns up to [maxCount] commits of the current branch, newest first.
  Future<List<GitCommitInfo>> gitLog({int maxCount = 50}) async {
    final raw = await _engine.gitLog(maxCount: maxCount);
    return (jsonDecode(raw) as List)
        .map((e) => GitCommitInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns every branch (local and remote) with its head metadata.
  Future<List<GitBranchInfo>> gitBranches() async {
    final raw = await _engine.gitBranches();
    return (jsonDecode(raw) as List)
        .map((e) => GitBranchInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Stages and commits all changes with [message] and the given identity.
  ///
  /// Returns the commit oid (sha) as a string.
  Future<String> gitCommit(
    String message, {
    required String authorName,
    required String authorEmail,
  }) async {
    final author = jsonEncode(
      GitCredentials(name: authorName, email: authorEmail).toJson(),
    );
    final raw = await _engine.gitCommit(message: message, authorJson: author);
    return (jsonDecode(raw) as Map<String, dynamic>)['oid'] as String;
  }

  /// Checks out a git [target] (branch name or commit).
  Future<void> gitCheckout(String target) =>
      _engine.gitCheckout(target: target);

  /// Pushes [branch] to its remote, using [credentials] when provided.
  Future<void> gitPush(String branch, {GitCredentials? credentials}) async {
    final creds = jsonEncode(
      (credentials ?? const GitCredentials(name: '', email: '')).toJson(),
    );
    await _engine.gitPush(branch: branch, credentialsJson: creds);
  }

  /// Pulls [branch] from its remote (fetch + merge) and returns the result.
  ///
  /// The result reports `up_to_date`, `fast_forward`, `merged` or `conflicts`.
  Future<GitMergeResult> gitPull(String branch,
      {GitCredentials? credentials}) async {
    final creds = jsonEncode(
      (credentials ?? const GitCredentials(name: '', email: '')).toJson(),
    );
    final raw = await _engine.gitPull(branch: branch, credentialsJson: creds);
    return GitMergeResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Resolves a merge conflict on [path] with the chosen [resolution].
  Future<void> gitResolveConflict(
    String path,
    ConflictResolution resolution,
  ) async {
    await _engine.gitResolveConflict(
      path: path,
      resolutionJson: jsonEncode(resolution.toJson()),
    );
  }

  /// Aborts an in-progress merge and returns to the pre-merge state.
  Future<void> gitAbortMerge() async {
    await _engine.gitAbortMerge();
  }

  /// Creates a snapshot zip of the project under [version] and returns its
  /// metadata.
  Future<SnapshotInfo> snapshotCreate({required int version}) async {
    final raw = await _engine.snapshotCreate(version: version);
    return SnapshotInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Lists the stored snapshots, newest first.
  Future<List<SnapshotInfo>> snapshotList() async {
    final raw = await _engine.snapshotList();
    return (jsonDecode(raw) as List)
        .map((e) => SnapshotInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Deletes the snapshot identified by [snapshotId] over the project
  Future<void> snapshotDelete(String snapshotId) =>
      _engine.snapshotDelete(snapshotId: snapshotId);

  /// Restores the snapshot identified by [snapshotId] over the project,
  /// overwriting current files.
  Future<void> snapshotRestore(String snapshotId) =>
      _engine.snapshotRestore(snapshotId: snapshotId);

  /// Creates a branch from the current HEAD.
  Future<void> gitBranchCreate(String name) =>
      _engine.gitBranchCreate(name: name);

  /// Creates a branch from a specific commit [oid].
  Future<void> gitBranchCreateFromCommit(String name, String oid) =>
      _engine.gitBranchCreateFromCommit(name: name, commitOid: oid);

  /// Switches to the branch named [name].
  Future<void> gitBranchSwitch(String name) =>
      _engine.gitBranchSwitch(name: name);

  /// Merges the branch named [name] into the current branch.
  Future<GitMergeResult> gitBranchMerge(String name) async {
    final raw = await _engine.gitBranchMerge(name: name);
    return GitMergeResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Deletes the branch named [name]; [force] drops unmerged branches.
  Future<void> gitBranchDelete(String name, {required bool force}) =>
      _engine.gitBranchDelete(name: name, force: force);

  /// Returns the current branch name.
  Future<String> gitCurrentBranch() async {
    final raw = await _engine.gitCurrentBranch();
    return (jsonDecode(raw) as Map<String, dynamic>)['name'] as String;
  }

  /// Fetches from the remote (default `origin`).
  Future<void> gitFetch(String remoteName,
      {GitCredentials? credentials}) async {
    final creds = jsonEncode(
      (credentials ?? const GitCredentials(name: '', email: '')).toJson(),
    );
    await _engine.gitFetch(remoteName: remoteName, credentialsJson: creds);
  }

  /// Detects every merge conflict in the repository.
  Future<List<GitConflictInfo>> gitConflictDetect() async {
    final raw = await _engine.gitConflictDetect();
    return (jsonDecode(raw) as List)
        .map((e) => GitConflictInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Resolves every conflicted file with the same [resolution].
  Future<void> gitConflictResolveAll(ConflictResolution resolution) async {
    await _engine.gitConflictResolveAll(
        resolutionJson: jsonEncode(resolution.toJson()));
  }

  /// Finishes the conflict resolution (clears the conflict state).
  Future<void> gitConflictFinish() => _engine.gitConflictFinish();

  /// Structural diff between two JSON-serialized document trees, or `null`
  /// when the payloads are not readable as documents.
  Future<GitTreeDiff?> gitDiffJsonDocuments(
      String oldJson, String newJson) async {
    final raw =
        await _engine.gitDiffJsonDocuments(oldJson: oldJson, newJson: newJson);
    return raw == 'null'
        ? null
        : GitTreeDiff.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Structural diff between two document nodes by uuid, or `null`.
  Future<GitTreeDiff?> gitDiffDocuments(String oldUuid, String newUuid) async {
    final raw =
        await _engine.gitDiffDocuments(oldUuid: oldUuid, newUuid: newUuid);
    return raw == 'null'
        ? null
        : GitTreeDiff.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Diff introduced by the last commit of [branch], or `null`.
  Future<GitCommitDiff?> gitLastCommitDiff(String branch) async {
    final raw = await _engine.gitLastCommitDiff(branch: branch);
    return raw == 'null'
        ? null
        : GitCommitDiff.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Diff between two commits, or `null`.
  Future<GitCommitDiff?> gitDiffBetweenCommits(
      String oldOid, String newOid) async {
    final raw =
        await _engine.gitDiffBetweenCommits(oldOid: oldOid, newOid: newOid);
    return raw == 'null'
        ? null
        : GitCommitDiff.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Initializes the internal git repository (no-op when already present).
  Future<void> gitInit() => _engine.gitInit();

  /// Sets (adds or replaces) the URL of the remote named [name].
  Future<void> gitSetRemote(String name, String url) =>
      _engine.gitSetRemote(name: name, url: url);

  /// Returns the URL of the remote named [name], or `null` when not configured.
  Future<String?> gitRemoteUrl(String name) async {
    final raw = await _engine.gitRemoteUrl(name: name);
    return (jsonDecode(raw) as Map<String, dynamic>)['url'] as String?;
  }

  /// Lists the configured remotes with their URLs.
  Future<List<GitRemoteInfo>> gitRemotes() async {
    final raw = await _engine.gitRemotes();
    return (jsonDecode(raw) as List)
        .map((e) => GitRemoteInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
