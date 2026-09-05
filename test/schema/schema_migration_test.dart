import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/schema/migration/schema_migration.dart';
import 'package:novident_project_manager/src/schema/registry.dart';

/// Test migration that stamps a boolean key per applied step.
class _StampingMigration extends SchemaMigration {
  const _StampingMigration(this.from, this.to, this.key);

  @override
  final int from;

  @override
  final int to;

  final String key;

  @override
  Map<String, dynamic> apply(Map<String, dynamic> json) {
    return <String, dynamic>{...json, key: true};
  }
}

void main() {
  test('current migrator targets the registry schema version', () {
    final migrator = SchemaMigrator.current();
    expect(migrator.currentVersion, kCurrentSchemaVersion);
  });

  test('a map on the current version is returned unchanged', () {
    final migrator = SchemaMigrator(currentVersion: 1);
    final input = <String, dynamic>{'schema_version': 1, 'a': 1};
    final result = migrator.migrateMap(input);

    expect(result['schema_version'], 1);
    expect(result['a'], 1);
  });

  test('a map without a schema_version marker is treated as current', () {
    final migrator = SchemaMigrator(currentVersion: 1);
    final input = <String, dynamic>{'a': 1};
    final result = migrator.migrateMap(input);

    expect(result, <String, dynamic>{'a': 1});
  });

  test('a newer schema_version is rejected with a clear error', () {
    final migrator = SchemaMigrator(currentVersion: 1);
    expect(
      () => migrator.migrateMap(const <String, dynamic>{'schema_version': 2}),
      throwsA(isA<SchemaTooNewException>()
          .having((e) => e.fileVersion, 'fileVersion', 2)
          .having((e) => e.currentVersion, 'currentVersion', 1)),
    );
  });

  test('the role is propagated into the too-new error', () {
    final migrator = SchemaMigrator(currentVersion: 1);
    try {
      migrator.migrateMap(const <String, dynamic>{'schema_version': 3},
          role: 'metadata');
      fail('expected SchemaTooNewException');
    } on SchemaTooNewException catch (e) {
      expect(e.role, 'metadata');
      expect(e.toString(), contains('metadata'));
    }
  });

  test('an old map is migrated step by step and stamped current', () {
    final migrator = SchemaMigrator(
      currentVersion: 3,
      migrations: <SchemaMigration>[
        _StampingMigration(2, 3, 'three'),
        _StampingMigration(1, 2, 'two'),
      ],
    );

    final input = <String, dynamic>{'schema_version': 1, 'a': 1};
    final result = migrator.migrateMap(input);

    expect(result['schema_version'], 3);
    expect(result['two'], isTrue);
    expect(result['three'], isTrue);
    expect(result['a'], 1);
  });

  test('the input map is not mutated', () {
    final migrator = SchemaMigrator(
      currentVersion: 2,
      migrations: <SchemaMigration>[_StampingMigration(1, 2, 'two')],
    );

    final input = <String, dynamic>{'schema_version': 1, 'a': 1};
    migrator.migrateMap(input);

    expect(input, <String, dynamic>{'schema_version': 1, 'a': 1});
  });

  test('a missing migration step raises a version gap error', () {
    final migrator = SchemaMigrator(currentVersion: 2);
    expect(
      () => migrator
          .migrateMap(const <String, dynamic>{'schema_version': 1}),
      throwsA(isA<SchemaVersionGapException>()
          .having((e) => e.fromVersion, 'fromVersion', 1)
          .having((e) => e.currentVersion, 'currentVersion', 2)),
    );
  });
}
