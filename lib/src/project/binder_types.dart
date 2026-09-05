// ignore_for_file: non_constant_identifier_names

/// Flat entry of the binder `lookup`: id → position metadata.
///
/// Mirrors one entry of `binder.index.json` → `lookup`. [LookupEntry] is
/// derived from the tree (recomputed on every persist) but it is exposed as a
/// typed model so the app can query nodes by id without walking the tree.
class LookupEntry {
  const LookupEntry({
    required this.name,
    required this.nodeType,
    required this.parentId,
    required this.path,
    required this.depth,
    this.folderType,
    this.trashed = false,
    this.childCount,
  });

  /// Display name of the node.
  final String name;

  /// `folder` or `document`.
  final String nodeType;

  /// Type of the parent folder (`manuscript`, `research`, `normal`, `trash`,
  /// `templatesSheet`) for folders.
  final String? folderType;

  /// Id of the node's parent (the project root id for top-level nodes).
  final String parentId;

  /// Path of the node as a list of child indexes from the root.
  final List<int> path;

  /// Depth of the node (1 = direct child of the root).
  final int depth;

  /// Whether the node is trashed.
  final bool trashed;

  /// Number of direct children, only present for folders.
  final int? childCount;

  /// Parses an entry from its on-disk JSON object.
  factory LookupEntry.fromJson(Map<String, dynamic> json) => LookupEntry(
        name: json['name'] as String? ?? '',
        nodeType: json['node_type'] as String? ?? 'document',
        folderType: json['folder_type'] as String?,
        parentId: json['parent_id'] as String? ?? '',
        path: (json['position'] as List?)?.cast<int>() ?? const <int>[],
        depth: json['depth'] as int? ?? 0,
        trashed: json['trashed'] as bool? ?? false,
        childCount: json['child_count'] as int?,
      );

  /// Serializes the entry to its on-disk JSON object.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'node_type': nodeType,
        if (folderType != null) 'folder_type': folderType,
        'parent_id': parentId,
        'path': path,
        'depth': depth,
        if (childCount != null) 'child_count': childCount,
        if (trashed) 'trashed': true,
      };
}

/// Metadata of one external file (`binder.index.json` → `external_files`).
///
/// External files live in `files/external/<id>.<ext>` and are attached to a
/// binder node via [attachedTo].
class ExternalFile {
  const ExternalFile({
    required this.id,
    required this.name,
    required this.extension,
    required this.attachedTo,
    required this.path,
    this.sizeBytes = 0,
  });

  /// File key: `<id>.<extension>`.
  final String id;

  /// Display name of the file.
  final String name;

  /// File extension (without the dot).
  final String extension;

  /// Id of the binder node the file is attached to.
  final String attachedTo;

  /// Path of the file inside the project (`files/external/<key>`).
  final String path;

  /// Size of the file in bytes.
  final int sizeBytes;

  /// Parses a file entry from its on-disk JSON object.
  factory ExternalFile.fromJson(String id, Map<String, dynamic> json) =>
      ExternalFile(
        id: id,
        name: json['name'] as String? ?? '',
        extension: json['extension'] as String? ?? '',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        attachedTo: json['attached_to'] as String? ?? '',
        path: json['path'] as String? ?? '',
      );

  /// Serializes the file entry to its on-disk JSON object.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'extension': extension,
        'size_bytes': sizeBytes,
        'attached_to': attachedTo,
        'path': path,
      };
}
