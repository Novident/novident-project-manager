import 'dart:convert';

import 'package:novident_document_format/novident_document_format.dart';

import 'package:novident_project_manager/src/project/binder_codec.dart';

import '../schema/registry.dart';

/// I/O boundary for the binder (`indexation/binder.index.json`).
abstract class BinderIo {
  Future<String?> readBinder();
  Future<void> writeBinder(String json);
}

/// Stateful host of the binder tree.
///
/// Decodes the binder once ([load]) and keeps the decoded `Folder` root plus
/// the file's header (version + timestamps) so [persist] can re-encode the tree
/// with `lookup` recomputed while preserving the header. Tree mutations go
/// through `BinderActions` and are flushed with [persist].
class BinderStore {
  BinderStore({required this.io});

  final BinderIo io;

  Binder? _binder;
  int _version = 1;
  int? _schemaVersion;
  String? _createdAt;

  /// The decoded binder; throws until [load] succeeds.
  Binder get binder {
    final Binder? value = _binder;
    if (value == null) throw StateError('binder is not loaded');
    return value;
  }

  Folder get root => binder.root;

  bool get isLoaded => _binder != null;

  /// Decodes `indexation/binder.index.json` from [io] (once).
  Future<Binder> load() async {
    final Binder? cached = _binder;
    if (cached != null) return cached;

    final String? json = await io.readBinder();
    if (json == null) throw StateError('binder not found');

    final Map<String, dynamic> map = jsonDecode(json) as Map<String, dynamic>;
    _version = map['version'] as int? ?? 1;
    _schemaVersion = map['schema_version'] as int? ?? kCurrentSchemaVersion;
    _createdAt = map['created_at'] as String?;
    _binder = BinderCodec.decode(map);
    return _binder!;
  }

  /// Re-encodes the in-memory tree (recomputing `lookup`/`external_files`),
  /// bumps `updated_at`, and writes the binder back through [io].
  Future<void> persist() async {
    final Binder value = binder;
    final String json = jsonEncode(BinderCodec.encode(
      projectId: value.projectId,
      projectName: value.projectName,
      root: value.root,
      version: _version,
      schemaVersion: _schemaVersion,
      createdAt: _createdAt,
      updatedAt: DateTime.now().toIso8601String(),
      externalFiles: value.externalFiles,
    ));
    await io.writeBinder(json);
  }

  /// Drops the cached state so the next [load] reads from disk again.
  void clear() {
    _binder = null;
    _version = 1;
    _schemaVersion = null;
    _createdAt = null;
  }
}
