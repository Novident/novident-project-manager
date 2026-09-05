import 'package:novident_project_manager/src/schema/registry.dart';

/// Raised when a schema file declares a `schema_version` newer than this layer
/// understands. The file must not be opened for writing until the app is
/// upgraded (a downgrade would corrupt it).
class SchemaTooNewException implements Exception {
  const SchemaTooNewException({
    required this.fileVersion,
    required this.currentVersion,
    this.role,
  });

  final int fileVersion;
  final int currentVersion;
  final String? role;

  @override
  String toString() =>
      'SchemaTooNewException: ${role != null ? '$role ' : ''}declares '
      'schema_version $fileVersion but this app only supports up to '
      '$currentVersion. Open it with a newer version.';
}

/// Raised when a schema file is older than current but no migration chain is
/// registered to bring it up to date.
class SchemaVersionGapException implements Exception {
  const SchemaVersionGapException({
    required this.fromVersion,
    required this.currentVersion,
    this.role,
  });

  final int fromVersion;
  final int currentVersion;
  final String? role;

  @override
  String toString() =>
      'SchemaVersionGapException: ${role != null ? '$role ' : ''}is on '
      'schema_version $fromVersion and no migration path to '
      '$currentVersion is registered.';
}

/// One version bump of a schema file.
///
/// Implementations migrate the raw JSON map from [from] to [to] (to is always
/// `from + 1`). Field-level schema is owned by Dart, so a migration is simply a
/// map transform that is applied before the model codec parses the file.
abstract class SchemaMigration {
  const SchemaMigration();

  /// The version this migration reads.
  int get from;

  /// The version this migration produces.
  int get to;

  /// Migrates [json] in place semantically and returns the migrated map.
  Map<String, dynamic> apply(Map<String, dynamic> json);
}

/// Chains [SchemaMigration]s up to the current schema version.
///
/// Usage:
/// ```dart
/// final migrator = SchemaMigrator(
///   currentVersion: 2,
///   migrations: [MyMigration1To2()],
/// );
/// final migrated = migrator.migrateMap(rawJson);
/// ```
class SchemaMigrator {
  SchemaMigrator({
    required this.currentVersion,
    Iterable<SchemaMigration> migrations = const <SchemaMigration>[],
  }) : _migrations = List<SchemaMigration>.of(migrations)
          ..sort((SchemaMigration a, SchemaMigration b) => a.from - b.from);

  /// Builds the migrator for the schema version this layer currently reads.
  factory SchemaMigrator.current() =>
      SchemaMigrator(currentVersion: kCurrentSchemaVersion);

  /// Highest version the schema layer can read/write.
  final int currentVersion;

  /// Registered migrations, sorted by their source version.
  final List<SchemaMigration> _migrations;

  /// Migrates a raw schema file map to [currentVersion].
  ///
  /// - Missing `schema_version` is treated as already current: the marker was
  ///   introduced with v1, so a file without it predates versioning and its
  ///   content is v1-shaped.
  /// - A newer version raises [SchemaTooNewException].
  /// - An older version is stepped through the registered chain; a missing
  ///   step raises [SchemaVersionGapException].
  Map<String, dynamic> migrateMap(Map<String, dynamic> json, {String? role}) {
    final Object? marker = json['schema_version'];
    if (marker is! int) {
      return Map<String, dynamic>.of(json);
    }
    if (marker == currentVersion) {
      return Map<String, dynamic>.of(json);
    }
    if (marker > currentVersion) {
      throw SchemaTooNewException(
        fileVersion: marker,
        currentVersion: currentVersion,
        role: role,
      );
    }

    Map<String, dynamic> result = Map<String, dynamic>.of(json);
    int version = marker;
    while (version < currentVersion) {
      SchemaMigration? step;
      for (final SchemaMigration migration in _migrations) {
        if (migration.from == version && migration.to == version + 1) {
          step = migration;
          break;
        }
      }
      if (step == null) {
        throw SchemaVersionGapException(
          fromVersion: version,
          currentVersion: currentVersion,
          role: role,
        );
      }
      result = step.apply(result);
      version = step.to;
    }
    result['schema_version'] = currentVersion;
    return result;
  }
}
