/// Options controlling a search query.
class SearchOptions {
  /// Creates search options; all fields default to the engine's behavior.
  const SearchOptions({
    this.caseSensitive = false,
    this.regexp = false,
    this.wholeWord = false,
    this.scopeIds,
    this.maxResults,
  });

  /// Whether the query is matched case-sensitively.
  final bool caseSensitive;

  /// Whether [query] is a regular expression instead of plain text.
  final bool regexp;

  /// Whether matches must align to whole words.
  final bool wholeWord;

  /// Explicit set of node ids to search (Dart resolves folders into ids).
  final List<String>? scopeIds;

  /// Maximum number of matches to return.
  final int? maxResults;

  /// Serializes the options to the engine's snake_case JSON shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'case_sensitive': caseSensitive,
        'regexp': regexp,
        'whole_word': wholeWord,
        if (scopeIds != null) 'scope_ids': scopeIds,
        if (maxResults != null) 'max_results': maxResults,
      };
}

/// A quick-search match (document-level, offset in one plain-text field).
class SearchMatch {
  /// Creates a quick-search match with the given hit details.
  const SearchMatch({
    required this.nodeId,
    required this.field,
    required this.offset,
    required this.length,
    this.preview,
  });

  /// Id of the document node that contains the hit.
  final String nodeId;

  /// Plain-text field of the document the hit lives in (`title`, `text`,
  /// `synopsis`, `notes`, `comments`).
  final String field;

  /// Character offset of the hit inside the field's text.
  final int offset;

  /// Length (in characters) of the hit.
  final int length;

  /// Snippet of surrounding text, when the engine provides one.
  final String? preview;

  /// Parses a quick-search match from the engine's JSON object.
  factory SearchMatch.fromJson(Map<String, dynamic> json) => SearchMatch(
        nodeId: json['node_id'] as String,
        field: json['field'] as String,
        offset: json['offset'] as int,
        length: json['length'] as int,
        preview: json['preview'] as String?,
      );
}

/// A full (structural) search match, resolved to the containing block.
class StructuralMatch {
  /// Creates a structural match with its block path.
  const StructuralMatch({
    required this.nodeId,
    required this.path,
    required this.blockType,
    required this.offset,
    required this.length,
    required this.preview,
  });

  /// Id of the document node that contains the hit.
  final String nodeId;

  /// Index path of the containing block inside the document tree.
  final List<int> path;

  /// Block type of the containing block (e.g. `paragraph`).
  final String blockType;

  /// Character offset of the hit inside the block's text.
  final int offset;

  /// Length (in characters) of the hit.
  final int length;

  /// Snippet of surrounding text.
  final String preview;

  /// Parses a structural match from the engine's JSON object.
  factory StructuralMatch.fromJson(Map<String, dynamic> json) =>
      StructuralMatch(
        nodeId: json['node_id'] as String,
        path: (json['path'] as List).cast<int>(),
        blockType: json['block_type'] as String,
        offset: json['offset'] as int,
        length: json['length'] as int,
        preview: json['preview'] as String,
      );
}

/// Status of the in-memory search index.
class SearchIndexStatus {
  /// Creates an index-status snapshot.
  const SearchIndexStatus({
    required this.dirtyCount,
    required this.stale,
    this.lastReindexAt,
  });

  /// Number of files changed since the index was last rebuilt.
  final int dirtyCount;

  /// Whether the index is out of date and should be rebuilt.
  final bool stale;

  /// ISO timestamp of the last reindex, when one has run.
  final String? lastReindexAt;

  /// Parses an index-status snapshot from the engine's JSON object.
  factory SearchIndexStatus.fromJson(Map<String, dynamic> json) =>
      SearchIndexStatus(
        dirtyCount: json['dirty_count'] as int,
        stale: json['stale'] as bool,
        lastReindexAt: json['last_reindex_at'] as String?,
      );
}

/// A git working-tree status entry.
class GitStatusEntry {
  /// Creates a status entry with its flags.
  const GitStatusEntry({
    required this.path,
    required this.status,
    required this.isNew,
    required this.isModified,
    required this.isDeleted,
    required this.isConflicted,
  });

  /// Path of the file, relative to the project root.
  final String path;

  /// Raw status string from git (e.g. `IndexModified`, `WtNew`).
  final String status;

  /// Whether the file is newly added.
  final bool isNew;

  /// Whether the file is modified.
  final bool isModified;

  /// Whether the file is deleted.
  final bool isDeleted;

  /// Whether the file is part of an unresolved merge conflict.
  final bool isConflicted;

  /// Parses a status entry from the engine's JSON object.
  factory GitStatusEntry.fromJson(Map<String, dynamic> json) => GitStatusEntry(
        path: json['path'] as String,
        status: json['status'] as String,
        isNew: json['is_new'] as bool,
        isModified: json['is_modified'] as bool,
        isDeleted: json['is_deleted'] as bool,
        isConflicted: json['is_conflicted'] as bool,
      );
}

/// A commit in the history log.
class GitCommitInfo {
  /// Creates a commit entry.
  const GitCommitInfo({
    required this.oid,
    required this.summary,
    required this.message,
    required this.author,
    required this.time,
  });

  /// Full commit id (sha).
  final String oid;

  /// One-line summary of the commit message.
  final String summary;

  /// Full commit message.
  final String message;

  /// Author string, as stored by git.
  final String author;

  /// Commit timestamp (Unix epoch seconds).
  final int time;

  /// Parses a commit entry from the engine's JSON object.
  factory GitCommitInfo.fromJson(Map<String, dynamic> json) => GitCommitInfo(
        oid: json['oid'] as String,
        summary: json['summary'] as String,
        message: json['message'] as String,
        author: json['author'] as String,
        time: json['time'] as int,
      );
}

/// A branch summary.
class GitBranchInfo {
  /// Creates a branch summary.
  const GitBranchInfo({
    required this.name,
    required this.isHead,
    required this.isLocal,
    required this.isRemote,
    required this.commitOid,
    this.upstreamName,
    this.commitSummary,
  });

  /// Branch name.
  final String name;

  /// Whether this is the branch currently checked out.
  final bool isHead;

  /// Whether the branch exists locally.
  final bool isLocal;

  /// Whether the branch is a remote-tracking branch.
  final bool isRemote;

  /// Commit id the branch points to.
  final String commitOid;

  /// Upstream remote branch name, when configured.
  final String? upstreamName;

  /// Summary of the branch's head commit, when available.
  final String? commitSummary;

  /// Parses a branch summary from the engine's JSON object.
  factory GitBranchInfo.fromJson(Map<String, dynamic> json) => GitBranchInfo(
        name: json['name'] as String,
        isHead: json['is_head'] as bool,
        isLocal: json['is_local'] as bool,
        isRemote: json['is_remote'] as bool,
        commitOid: json['commit_oid'] as String,
        upstreamName: json['upstream_name'] as String?,
        commitSummary: json['commit_summary'] as String?,
      );
}

/// Result of a merge/pull (tagged enum from Rust serde).
class GitMergeResult {
  /// Creates a merge result; [conflicts] only matters when [type] is
  /// `conflicts`.
  const GitMergeResult({required this.type, this.conflicts});

  /// One of `up_to_date`, `fast_forward`, `merged`, `conflicts`.
  final String type;

  /// Paths of conflicting files, when the merge finished with conflicts.
  final List<String>? conflicts;

  /// Whether the merge/pull found nothing to do.
  bool get isUpToDate => type == 'up_to_date';

  /// Whether the merge/pull fast-forwarded.
  bool get isFastForward => type == 'fast_forward';

  /// Whether the merge/pull completed cleanly.
  bool get isMerged => type == 'merged';

  /// Whether the merge/pull left conflicts to resolve.
  bool get hasConflicts => type == 'conflicts';

  /// Parses a merge result from the engine's JSON object.
  factory GitMergeResult.fromJson(Map<String, dynamic> json) => GitMergeResult(
        type: json['type'] as String,
        conflicts: (json['conflicts'] as List?)?.cast<String>(),
      );
}

/// Git credentials (commit author and/or remote auth).
class GitCredentials {
  /// Creates credentials; [name] and [email] identify the author, the rest
  /// configure remote authentication (SSH key or HTTPS token).
  const GitCredentials({
    required this.name,
    required this.email,
    this.sshKeyPath,
    this.sshPublicKey,
    this.httpsToken,
    this.remoteUrl,
  });

  /// Author name used for commits.
  final String name;

  /// Author email used for commits.
  final String email;

  /// Path to the SSH private key used for remote authentication.
  final String? sshKeyPath;

  /// SSH public key (optional, paired with [sshKeyPath]).
  final String? sshPublicKey;

  /// HTTPS token used for remote authentication.
  final String? httpsToken;

  /// Remote URL these credentials apply to.
  final String? remoteUrl;

  /// Serializes the credentials to the engine's snake_case JSON shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'email': email,
        if (sshKeyPath != null) 'ssh_key_path': sshKeyPath,
        if (sshPublicKey != null) 'ssh_public_key': sshPublicKey,
        if (httpsToken != null) 'https_token': httpsToken,
        if (remoteUrl != null) 'remote_url': remoteUrl,
      };
}

/// A merge-conflict resolution choice (tagged enum from Rust serde).
class ConflictResolution {
  /// Accepts the current (local) side of the conflict.
  const ConflictResolution.ours()
      : type = 'accept_ours',
        content = null;

  /// Accepts the incoming (remote) side of the conflict.
  const ConflictResolution.theirs()
      : type = 'accept_theirs',
        content = null;

  /// Replaces the conflicted file with a custom [content].
  const ConflictResolution.custom(this.content) : type = 'custom';

  /// Discriminator of the resolution (`accept_ours`, `accept_theirs`,
  /// `custom`).
  final String type;

  /// Replacement content, only used by the `custom` resolution.
  final String? content;

  /// Serializes the resolution to the engine's JSON shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        if (content != null) 'content': content,
      };
}

/// Metadata for a stored project snapshot.
class SnapshotInfo {
  /// Creates snapshot metadata.
  const SnapshotInfo({
    required this.id,
    required this.filename,
    required this.createdAt,
  });

  /// Snapshot id (used to restore it).
  final String id;

  /// File name of the snapshot in `snapshots/`.
  final String filename;

  /// Creation timestamp (Unix epoch seconds).
  final int createdAt;

  /// Parses snapshot metadata from the engine's JSON object.
  factory SnapshotInfo.fromJson(Map<String, dynamic> json) => SnapshotInfo(
        id: json['id'] as String,
        filename: json['filename'] as String,
        createdAt: json['created_at'] as int,
      );
}

/// Severity of a structural-validation issue.
enum ValidationSeverity {
  /// The issue breaks the structural contract and must be fixed.
  error,

  /// The issue is a warning and does not block the project.
  warning,
}

/// A single structural-validation issue.
class ValidationIssue {
  /// Creates a validation issue.
  const ValidationIssue({
    required this.severity,
    required this.path,
    required this.code,
    required this.message,
  });

  /// Severity of the issue ([ValidationSeverity.error] or `warning`).
  final ValidationSeverity severity;

  /// Path of the file the issue refers to.
  final String path;

  /// Stable machine-readable code of the check that failed.
  final String code;

  /// Human-readable description of the issue.
  final String message;

  /// Parses a validation issue from the engine's JSON object.
  factory ValidationIssue.fromJson(Map<String, dynamic> json) =>
      ValidationIssue(
        severity: json['severity'] == 'error'
            ? ValidationSeverity.error
            : ValidationSeverity.warning,
        path: json['path'] as String,
        code: json['code'] as String,
        message: json['message'] as String,
      );
}

/// A single conflicted file reported by [git_conflict_detect].
class GitConflictInfo {
  const GitConflictInfo({
    required this.path,
    required this.oursDeleted,
    required this.theirsDeleted,
    this.oursContent,
    this.theirsContent,
    this.ancestorContent,
  });

  /// Relative path of the conflicted file.
  final String path;

  /// Content of the current (ours) side, when present.
  final String? oursContent;

  /// Content of the incoming (theirs) side, when present.
  final String? theirsContent;

  /// Content of the common ancestor, when present.
  final String? ancestorContent;

  /// Whether the file was deleted on the ours side.
  final bool oursDeleted;

  /// Whether the file was deleted on the theirs side.
  final bool theirsDeleted;

  /// Parses a conflict from the engine JSON object (tolerant of missing
  /// fields).
  factory GitConflictInfo.fromJson(Map<String, dynamic> json) =>
      GitConflictInfo(
        path: json['path'] as String? ?? '',
        oursContent: json['ours_content'] as String?,
        theirsContent: json['theirs_content'] as String?,
        ancestorContent: json['ancestor_content'] as String?,
        oursDeleted: json['ours_deleted'] as bool? ?? false,
        theirsDeleted: json['theirs_deleted'] as bool? ?? false,
      );
}

/// Structural document diff (`TreeDiff`) returned by the engine.
class GitTreeDiff {
  const GitTreeDiff({
    required this.nodesAdded,
    required this.nodesRemoved,
    required this.nodesModified,
    required this.nodesMoved,
    required this.summary,
    this.changes = const <Map<String, dynamic>>[],
  });

  final int nodesAdded;
  final int nodesRemoved;
  final int nodesModified;
  final int nodesMoved;

  /// Human-readable summary.
  final String summary;

  /// Raw change entries (tagged by `change_type`).
  final List<Map<String, dynamic>> changes;

  /// Parses a tree diff from the engine JSON object.
  factory GitTreeDiff.fromJson(Map<String, dynamic> json) => GitTreeDiff(
        nodesAdded: json['nodes_added'] as int? ?? 0,
        nodesRemoved: json['nodes_removed'] as int? ?? 0,
        nodesModified: json['nodes_modified'] as int? ?? 0,
        nodesMoved: json['nodes_moved'] as int? ?? 0,
        summary: json['summary'] as String? ?? '',
        changes: (json['changes'] as List? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
}

/// Per-file diff inside a commit diff.
class GitFileDiff {
  const GitFileDiff({
    required this.path,
    required this.status,
    this.contentDiff,
  });

  final String path;
  final String status;

  /// Structural content diff for JSON content files, `null` otherwise.
  final GitTreeDiff? contentDiff;

  /// Parses a file diff from the engine JSON object.
  factory GitFileDiff.fromJson(Map<String, dynamic> json) => GitFileDiff(
        path: json['path'] as String? ?? '',
        status: json['status'] as String? ?? '',
        contentDiff: json['content_diff'] is Map<String, dynamic>
            ? GitTreeDiff.fromJson(
                json['content_diff'] as Map<String, dynamic>)
            : null,
      );
}

/// Diff introduced by a commit.
class GitCommitDiff {
  const GitCommitDiff({
    required this.commitOid,
    required this.commitMessage,
    required this.commitAuthor,
    required this.commitTime,
    required this.fileDiffs,
  });

  final String commitOid;
  final String commitMessage;
  final String commitAuthor;
  final String commitTime;
  final List<GitFileDiff> fileDiffs;

  /// Parses a commit diff from the engine JSON object.
  factory GitCommitDiff.fromJson(Map<String, dynamic> json) => GitCommitDiff(
        commitOid: json['commit_oid'] as String? ?? '',
        commitMessage: json['commit_message'] as String? ?? '',
        commitAuthor: json['commit_author'] as String? ?? '',
        commitTime: json['commit_time'] as String? ?? '',
        fileDiffs: (json['file_diffs'] as List? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(GitFileDiff.fromJson)
            .toList(),
      );
}

/// A configured git remote and its URL.
class GitRemoteInfo {
  const GitRemoteInfo({required this.name, this.url});

  /// Remote name (e.g. `origin`).
  final String name;

  /// Remote URL, when configured.
  final String? url;

  /// Parses a remote from the engine JSON object.
  factory GitRemoteInfo.fromJson(Map<String, dynamic> json) => GitRemoteInfo(
        name: json['name'] as String? ?? '',
        url: json['url'] as String?,
      );
}
