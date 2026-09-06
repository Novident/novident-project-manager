import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_nodes/novident_nodes.dart';

import 'binder_types.dart';

/// The decoded binder: project identity + the root folder tree, plus the flat
/// metadata the file carries alongside it: the external-files map (kept up to
/// date by the caller and written back on [BinderCodec.encode]).
class Binder {
  Binder({
    required this.projectId,
    required this.projectName,
    required this.root,
    Map<String, ExternalFile>? externalFiles,
  }) : externalFiles = externalFiles ?? <String, ExternalFile>{};

  final String projectId;
  final String projectName;
  final Folder root;

  /// External files attached to binder nodes (`external_files`), keyed by their
  /// file key (`<id>.<ext>`). Mutable: consumers attach/detach files here and
  /// the codec writes them back on persist.
  final Map<String, ExternalFile> externalFiles;

  /// Recomputes the flat `lookup` from the current tree.
  ///
  /// The lookup is derived state (never trusted from disk): call this after
  /// any tree mutation to query nodes by id without walking the tree.
  Map<String, LookupEntry> recomputeLookup() =>
      BinderCodec.buildLookup(root, projectId: projectId);

  /// Returns the lookup entry of [id], or `null` when the node does not exist.
  LookupEntry? lookupFor(String id) {
    return recomputeLookup()[id];
  }
}

/// Maps the `.nov` binder (`indexation/binder.index.json`) to/from the
/// `novident_document_format` tree (`Folder` / `Document` / `DocumentResource`).
///
/// Mapping notes:
/// - `node_type` `"folder"` ↔ `Folder`, `"document"` ↔ `Document`.
/// - `folder_type` ↔ `FolderType` (by name).
/// - `attached_section` ↔ `attachedSection` (default `structured-based`).
/// - `path` is derived as `files/<id>` (not stored in the tree).
/// - `trashed_at`/`expires_at` ↔ `NodeTrashedOptions`.
/// - `resources`/`external_files` ↔ `DocumentResource` nodes (extracted to the
///   flat `external_files` map on encode, re-attached on decode).
/// - `lookup` is recomputed on encode (never persisted back).
class BinderCodec {
  BinderCodec._();

  /// Serializes the binder to its on-disk JSON map.
  ///
  /// [externalFiles] is optional: when given, its entries are written into the
  /// `external_files` block (external files present in the tree are always
  /// included, derived from their `DocumentResource` nodes).
  static Map<String, dynamic> encode({
    required String projectId,
    required String projectName,
    required Folder root,
    int version = 1,
    int? schemaVersion = 1,
    String? createdAt,
    String? updatedAt,
    Map<String, ExternalFile>? externalFiles,
  }) {
    final tree = <Map<String, dynamic>>[];
    final lookup = <String, Map<String, dynamic>>{};
    final encodedExternal = <String, Map<String, dynamic>>{
      ...?externalFiles?.map(
        (String key, ExternalFile file) => MapEntry(key, file.toJson()),
      )
    };

    for (var i = 0; i < root.children.length; i++) {
      final encoded = _encodeNode(
        root.children[i],
        lookup,
        encodedExternal,
        <int>[i],
        1,
        projectId,
      );
      if (encoded != null) {
        tree.add(encoded);
      }
    }

    return <String, dynamic>{
      'project_id': projectId,
      'project_name': projectName,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      'tree': tree,
      'lookup': lookup,
      'external_files': encodedExternal,
    };
  }

  /// Parses the binder from its on-disk JSON map.
  ///
  /// The decoded [Binder] keeps the external files that the file declares;
  /// `lookup` is not trusted and is rebuilt from the tree via
  /// [Binder.recomputeLookup]. `word_count` keys, if present, are ignored
  /// (statistics own the counts).
  static Binder decode(Map<String, dynamic> binder) {
    final projectId = binder['project_id'] as String? ?? '';
    final projectName = binder['project_name'] as String? ?? '';
    final externalRaw =
        (binder['external_files'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final externalFiles = externalRaw.map((String key, dynamic value) =>
        MapEntry(
            key,
            ExternalFile.fromJson(
                key, value as Map<String, dynamic>? ?? const {})));
    final tree = (binder['tree'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    final children = <Node>[
      for (final node in tree) _decodeNode(node, externalRaw),
    ];

    final root = Folder(
      children: children,
      name: projectName,
      details: NodeDetails.base(projectId),
      doRedepthCheck: true,
      isExpanded: true,
    );

    return Binder(
      projectId: projectId,
      projectName: projectName,
      root: root,
      externalFiles: externalFiles,
    );
  }

  /// Recomputes the flat lookup map of [root] (typed).
  ///
  /// [projectId] is used as the `parent_id` of top-level nodes; when omitted it
  /// falls back to the root id.
  static Map<String, LookupEntry> buildLookup(Folder root,
      {String? projectId}) {
    final Map<String, LookupEntry> lookup = <String, LookupEntry>{};
    final String rootId = projectId ?? root.id;

    void visit(Node node, List<int> position, int depth, String parentId) {
      if (node is DocumentResource) return;
      final bool isFolder = node is Folder;
      final String name = isFolder ? node.name : (node as Document).name;
      final bool trashed = isFolder
          ? node.trashStatus.isTrashed
          : (node as Document).trashStatus.isTrashed;
      lookup[node.id] = LookupEntry(
        name: name,
        nodeType: isFolder ? 'folder' : 'document',
        folderType: isFolder ? node.folderType.name : null,
        parentId: parentId,
        path: position,
        depth: depth,
        trashed: trashed,
        childCount: isFolder ? node.children.length : null,
      );
      if (isFolder) {
        for (var i = 0; i < node.children.length; i++) {
          visit(node.children[i], <int>[...position, i], depth + 1, node.id);
        }
      }
    }

    for (var i = 0; i < root.children.length; i++) {
      visit(root.children[i], <int>[i], 1, rootId);
    }
    return lookup;
  }

  /// Encodes a single node into `tree` (and populates `lookup`/`externalFiles`).
  /// Returns the node's JSON map, or `null` for a `DocumentResource` (handled by
  /// its parent via `external_files`/`resources`).
  static Map<String, dynamic>? _encodeNode(
    Node node,
    Map<String, Map<String, dynamic>> lookup,
    Map<String, Map<String, dynamic>> externalFiles,
    List<int> position,
    int depth,
    String parentId,
  ) {
    if (node is DocumentResource) {
      externalFiles[node.id] = <String, dynamic>{
        'name': node.name,
        'extension': node.extension,
        'size_bytes': 0,
        'attached_to': parentId,
        'path': node.path,
      };
      return null;
    }

    final bool isFolder = node is Folder;
    final String name = isFolder ? node.name : (node as Document).name;
    final String attachedSection =
        isFolder ? node.attachedSection : (node as Document).attachedSection;
    final NodeTrashedOptions trash =
        isFolder ? node.trashStatus : (node as Document).trashStatus;

    final map = <String, dynamic>{
      'id': node.id,
      'name': name,
      'node_type': isFolder ? 'folder' : 'document',
      'path': 'files/${node.id}',
      'attached_section': attachedSection,
    };

    if (isFolder) {
      map['folder_type'] = node.folderType.name;

      final children = <Map<String, dynamic>>[];
      final resources = <String>[];
      for (var i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final encoded = _encodeNode(
          child,
          lookup,
          externalFiles,
          <int>[...position, i],
          depth + 1,
          node.id,
        );
        if (child is DocumentResource) {
          resources.add(child.id);
        } else if (encoded != null) {
          children.add(encoded);
        }
      }
      map['children'] = children;
      if (resources.isNotEmpty) {
        map['resources'] = resources;
      }
    }

    if (trash.isTrashed) {
      map['trashed_at'] = DateTime.now().toIso8601String();
      if (trash.expire != null) {
        map['expires_at'] = trash.expire!.toIso8601String();
      }
    }

    lookup[node.id] = <String, dynamic>{
      'name': name,
      'node_type': map['node_type'],
      if (isFolder) 'folder_type': node.folderType.name,
      'parent_id': parentId,
      'path': map['path'],
      'position': position,
      'depth': depth,
      if (isFolder) 'child_count': node.children.length,
      if (trash.isTrashed) 'trashed': true,
    };

    return map;
  }

  static Node _decodeNode(
    Map<String, dynamic> node,
    Map<String, dynamic> externalFiles,
  ) {
    final id = node['id'] as String? ?? NodeDetails.createNodeId();
    final name = node['name'] as String? ?? '';
    final nodeType = node['node_type'] as String? ?? 'document';
    final attachedSection = node['attached_section'] as String? ??
        NovidentDefaults.kStructuredBasedSectionId;
    final trash = _decodeTrash(node);

    if (nodeType == 'folder') {
      final children = <Node>[
        for (final child
            in (node['children'] as List?)?.cast<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[])
          _decodeNode(child, externalFiles),
      ];
      for (final resourceId
          in (node['resources'] as List?)?.cast<String>() ?? const <String>[]) {
        final ext = externalFiles[resourceId] as Map<String, dynamic>?;
        if (ext != null) {
          children.add(_decodeResource(resourceId, ext));
        }
      }
      return Folder(
        children: children,
        name: name,
        details: NodeDetails.byId(level: 0, id: id),
        folderType: _folderTypeFromName(node['folder_type'] as String?),
        attachedSection: attachedSection,
        trashOptions: trash,
      );
    }

    return Document(
      details: NodeDetails.byId(level: 0, id: id),
      name: name,
      attachedSection: attachedSection,
      trashOptions: trash,
    );
  }

  static DocumentResource _decodeResource(String id, Map<String, dynamic> ext) {
    return DocumentResource(
      details: NodeDetails.byId(level: 0, id: id),
      name: ext['name'] as String? ?? '',
      extension: ext['extension'] as String? ?? '',
      path: ext['path'] as String? ?? '',
    );
  }

  static NodeTrashedOptions _decodeTrash(Map<String, dynamic> node) {
    final trashedAt = node['trashed_at'] as String?;
    if (trashedAt == null) {
      return const NodeTrashedOptions.nonTrashed();
    }
    final expiresAt = node['expires_at'] as String?;
    return NodeTrashedOptions(
      isTrashed: true,
      expire: expiresAt == null ? null : DateTime.tryParse(expiresAt),
    );
  }

  static FolderType _folderTypeFromName(String? name) {
    switch (name?.toLowerCase()) {
      case 'manuscript':
        return FolderType.manuscript;
      case 'research':
        return FolderType.research;
      case 'templatessheet':
        return FolderType.templatesSheet;
      case 'trash':
        return FolderType.trash;
      default:
        return FolderType.normal;
    }
  }
}
