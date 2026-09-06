import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:novident_project_manager/src/schema/registry.dart';

/// Backup manifest (`files/backup.json`): a compact mirror of the binder with
/// a checksum. Generated on save, never user-edited.
@experimental
class Backup {
  final int? schemaVersion;
  final String format;
  final int version;
  final String projectId;
  final String projectName;
  final String createdAt;
  final String checksum;
  final BackupTree tree;

  const Backup({
    this.schemaVersion = kCurrentSchemaVersion,
    this.format = 'novident_backup',
    this.version = 1,
    this.projectId = '',
    this.projectName = '',
    this.createdAt = '',
    this.checksum = '',
    this.tree = const BackupTree(),
  });

  factory Backup.fromJson(Map<String, dynamic> json) => Backup(
        schemaVersion: json['schema_version'] as int?,
        format: json['format'] as String? ?? 'novident_backup',
        version: json['version'] as int? ?? 1,
        projectId: json['project_id'] as String? ?? '',
        projectName: json['project_name'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        checksum: json['checksum'] as String? ?? '',
        tree: BackupTree.fromJson(
            json['tree'] as Map<String, dynamic>? ?? const {}),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (schemaVersion != null) 'schema_version': schemaVersion,
        'format': format,
        'version': version,
        'project_id': projectId,
        'project_name': projectName,
        'created_at': createdAt,
        'checksum': checksum,
        'tree': tree.toJson(),
      };

  String toJsonString() => json.encode(toJson());

  factory Backup.fromJsonString(String source) =>
      Backup.fromJson(json.decode(source) as Map<String, dynamic>);
}

/// Compact tree mirror. The on-disk entry keys are single letters (`n`/`t`/
/// `p`/`c`/`x`/`a`); the Dart fields use descriptive names and the codec maps
/// them so the serialized form stays byte-compatible with the format.
@experimental
class BackupTree {
  final String root;
  final Map<String, BackupFolder> folders;
  final Map<String, BackupDocument> documents;
  final Map<String, BackupExternal> external;

  const BackupTree({
    this.root = '',
    this.folders = const <String, BackupFolder>{},
    this.documents = const <String, BackupDocument>{},
    this.external = const <String, BackupExternal>{},
  });

  factory BackupTree.fromJson(Map<String, dynamic> json) {
    final rawFolders = json['folders'];
    final rawDocuments = json['documents'];
    final rawExternal = json['external'];
    return BackupTree(
      root: json['root'] as String? ?? '',
      folders: rawFolders is Map<String, dynamic>
          ? rawFolders.map((String id, dynamic value) => MapEntry(
              id, BackupFolder.fromJson(value as Map<String, dynamic>)))
          : const <String, BackupFolder>{},
      documents: rawDocuments is Map<String, dynamic>
          ? rawDocuments.map((String id, dynamic value) => MapEntry(
              id, BackupDocument.fromJson(value as Map<String, dynamic>)))
          : const <String, BackupDocument>{},
      external: rawExternal is Map<String, dynamic>
          ? rawExternal.map((String id, dynamic value) => MapEntry(
              id, BackupExternal.fromJson(value as Map<String, dynamic>)))
          : const <String, BackupExternal>{},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'root': root,
        'folders': folders.map(
            (String id, BackupFolder folder) => MapEntry(id, folder.toJson())),
        'documents': documents.map((String id, BackupDocument document) =>
            MapEntry(id, document.toJson())),
        'external': external.map((String id, BackupExternal external) =>
            MapEntry(id, external.toJson())),
      };
}

/// `{n, t, p, c}` — name, folder type, parent id (null at top level), children.
@experimental
class BackupFolder {
  final String name;
  final String type;
  final String? parent;
  final List<String> children;

  const BackupFolder({
    this.name = '',
    this.type = '',
    this.parent,
    this.children = const <String>[],
  });

  factory BackupFolder.fromJson(Map<String, dynamic> json) => BackupFolder(
        name: json['n'] as String? ?? '',
        type: json['t'] as String? ?? '',
        parent: json['p'] as String?,
        children: (json['c'] as List?)?.cast<String>() ?? const <String>[],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'n': name,
        't': type,
        'p': parent,
        'c': children,
      };
}

/// `{n, p, x?}` — name, parent id, trashed flag (only present when true).
@experimental
class BackupDocument {
  final String name;
  final String parent;
  final bool trashed;

  const BackupDocument({
    this.name = '',
    this.parent = '',
    this.trashed = false,
  });

  factory BackupDocument.fromJson(Map<String, dynamic> json) => BackupDocument(
        name: json['n'] as String? ?? '',
        parent: json['p'] as String? ?? '',
        trashed: json['x'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'n': name,
        'p': parent,
        if (trashed) 'x': true,
      };
}

/// `{n, a}` — name and the node id it is attached to.
@experimental
class BackupExternal {
  final String name;
  final String attachedTo;

  const BackupExternal({this.name = '', this.attachedTo = ''});

  factory BackupExternal.fromJson(Map<String, dynamic> json) => BackupExternal(
        name: json['n'] as String? ?? '',
        attachedTo: json['a'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'n': name,
        'a': attachedTo,
      };
}
