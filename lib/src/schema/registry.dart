// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import 'package:novident_project_manager/src/format/format.dart';
import 'package:novident_project_manager/src/layout/layout.dart';
import 'package:novident_project_manager/src/project/backup/backup.dart';
import 'package:novident_project_manager/src/project/binder_codec.dart';
import 'package:novident_project_manager/src/project/corkboard/corkboard.dart';
import 'package:novident_project_manager/src/project/export/export.dart';
import 'package:novident_project_manager/src/project/icon/icon.dart';
import 'package:novident_project_manager/src/project/project_configurations.dart';
import 'package:novident_project_manager/src/project/section/section_manager.dart';
import 'package:novident_project_manager/src/project/sections_codec.dart';
import 'package:novident_project_manager/src/project/session/session.dart';
import 'package:novident_project_manager/src/project/target/target.dart';

/// Version of the `.nov` schema this Dart layer reads and writes.
///
/// Mirrors `rust/schema/schema-v1.yaml`: each format version has its own
/// `schema-v<N>.yaml`; a project's `schema_version` selects which one applies.
const int kCurrentSchemaVersion = 1;

/// Codec binding for one top-level schema file: a logical role, its path
/// relative to the project root, and a string-level codec (raw JSON in, raw
/// JSON out) so the registry stays engine-agnostic.
class SchemaFile<T> {
  const SchemaFile({
    required this.role,
    required this.path,
    required this.decode,
    required this.encode,
  });

  /// Logical role used across the schema layer (e.g. `metadata`).
  final String role;

  /// Path of the file relative to the project root.
  final String path;

  /// Parses the raw JSON string into the typed model.
  final T Function(String json) decode;

  /// Serializes the typed model back into a JSON string.
  final String Function(T value) encode;
}

/// Codec binding for one collection directory: a role, the directory that
/// holds one file per item, and the item's key field used for the file name.
class SchemaCollection<T> {
  const SchemaCollection({
    required this.role,
    required this.dir,
    required this.key,
    required this.decode,
    required this.encode,
  });

  /// Logical role used across the schema layer (e.g. `layouts`).
  final String role;

  /// Directory that holds one JSON file per item.
  final String dir;

  /// Field that identifies the item and names its file (`<dir>/<key>.json`).
  final String key;

  /// Parses one item's raw JSON string into the typed model.
  final T Function(String json) decode;

  /// Serializes one typed item back into a JSON string.
  final String Function(T value) encode;
}

/// Dart-side structural description of a `.nov` project.
///
/// This is the mirror of `rust/schema/schema-v1.yaml` that the Dart schema
/// layer (stores, reducer) uses as its source of truth for *what exists* and
/// *how files relate*, plus the codec binding for every typed schema file.
abstract final class SchemaRegistry {
  // -- structural contract (mirror of schema-v1.yaml) -----------------------

  /// Directories that must exist in a well-formed project.
  static const List<String> requiredDirs = <String>[
    'files',
    'files/external',
    'indexation',
    'history',
    'layouts',
    'compiler/formats',
    'compiler/exports',
    'snapshots',
  ];

  /// Files that must exist (and be parseable JSON). A missing one is a
  /// structural error (reported, never aborts opening).
  static const List<String> requiredFiles = <String>[
    'files/metadata.json',
    'files/backup.json',
    'indexation/binder.index.json',
    'indexation/sections.index.json',
    'indexation/icon.index.json',
    'indexation/corkboard.index.json',
    'indexation/search.index.json',
    'indexation/target.index.json',
  ];

  /// Optional files. Missing is a warning only.
  static const List<String> optionalFiles = <String>['.gitignore'];

  /// Files owned by the engine itself (Dart reads them, never writes).
  ///
  /// `indexation/search.index.json` is rebuilt by the engine's search
  /// subsystem, so it is intentionally absent from the writeable bindings.
  static const List<String> engineManagedFiles = <String>[
    'indexation/search.index.json',
  ];

  /// Collections: directories with one file per item, keyed by the given
  /// field (directory, item key field) — mirror of schema-v1.yaml.
  static const List<(String, String)> collectionDirs = <(String, String)>[
    ('layouts', 'id'),
    ('compiler/formats', 'id'),
    ('compiler/exports', 'id'),
    ('history', 'session_date'),
  ];

  // -- top-level schema files -----------------------------------------------

  /// `files/metadata.json` → [Metadata].
  static final SchemaFile<Metadata> metadata = SchemaFile<Metadata>(
    role: 'metadata',
    path: 'files/metadata.json',
    decode: (String json) =>
        Metadata.fromJson(jsonDecode(json) as Map<String, dynamic>),
    encode: (Metadata value) => jsonEncode(value.toJson()),
  );

  /// `files/backup.json` → [Backup].
  static final SchemaFile<Backup> backup = SchemaFile<Backup>(
    role: 'backup',
    path: 'files/backup.json',
    decode: Backup.fromJsonString,
    encode: (Backup value) => value.toJsonString(),
  );

  /// `indexation/binder.index.json` → [Binder] (the `novident_nodes` tree).
  static final SchemaFile<Binder> binder = SchemaFile<Binder>(
    role: 'binder',
    path: 'indexation/binder.index.json',
    decode: (String json) =>
        BinderCodec.decode(jsonDecode(json) as Map<String, dynamic>),
    encode: (Binder value) => jsonEncode(BinderCodec.encode(
          projectId: value.projectId,
          projectName: value.projectName,
          root: value.root,
          externalFiles: value.externalFiles,
        )),
  );

  /// `indexation/sections.index.json` → [SectionManager].
  static final SchemaFile<SectionManager> sections = SchemaFile<SectionManager>(
    role: 'sections',
    path: 'indexation/sections.index.json',
    decode: SectionsCodec.decode,
    encode: SectionsCodec.encode,
  );

  /// `indexation/icon.index.json` → [IconIndex].
  static final SchemaFile<IconIndex> icon = SchemaFile<IconIndex>(
    role: 'icon',
    path: 'indexation/icon.index.json',
    decode: IconIndex.fromJsonString,
    encode: (IconIndex value) => value.toJsonString(),
  );

  /// `indexation/corkboard.index.json` → [CorkboardIndex].
  static final SchemaFile<CorkboardIndex> corkboard = SchemaFile<CorkboardIndex>(
    role: 'corkboard',
    path: 'indexation/corkboard.index.json',
    decode: CorkboardIndex.fromJsonString,
    encode: (CorkboardIndex value) => value.toJsonString(),
  );

  /// `indexation/target.index.json` → [TargetIndex].
  static final SchemaFile<TargetIndex> target = SchemaFile<TargetIndex>(
    role: 'target',
    path: 'indexation/target.index.json',
    decode: TargetIndex.fromJsonString,
    encode: (TargetIndex value) => value.toJsonString(),
  );

  /// Role → path of every writeable top-level schema file.
  ///
  /// The codec bindings above are typed; use this map (or [requiredFiles]) for
  /// structural iteration and error messages without touching the typed codecs.
  static const Map<String, String> topLevelPaths = <String, String>{
    'metadata': 'files/metadata.json',
    'backup': 'files/backup.json',
    'binder': 'indexation/binder.index.json',
    'sections': 'indexation/sections.index.json',
    'icon': 'indexation/icon.index.json',
    'corkboard': 'indexation/corkboard.index.json',
    'target': 'indexation/target.index.json',
  };

  // -- collections ----------------------------------------------------------

  /// `layouts/<id>.json` → [Layout].
  static final SchemaCollection<Layout> layouts = SchemaCollection<Layout>(
    role: 'layouts',
    dir: 'layouts',
    key: 'id',
    decode: Layout.fromJson,
    encode: (Layout value) => value.toJson(),
  );

  /// `compiler/formats/<id>.json` → [Format].
  static final SchemaCollection<Format> formats = SchemaCollection<Format>(
    role: 'formats',
    dir: 'compiler/formats',
    key: 'id',
    decode: Format.fromJson,
    encode: (Format value) => value.toJson(),
  );

  /// `compiler/exports/<id>.json` → [Export].
  static final SchemaCollection<Export> exports = SchemaCollection<Export>(
    role: 'exports',
    dir: 'compiler/exports',
    key: 'id',
    decode: Export.fromJsonString,
    encode: (Export value) => value.toJsonString(),
  );

  /// `history/<session_date>.json` → [Session].
  static final SchemaCollection<Session> sessions = SchemaCollection<Session>(
    role: 'sessions',
    dir: 'history',
    key: 'session_date',
    decode: Session.fromJsonString,
    encode: (Session value) => value.toJsonString(),
  );
}
