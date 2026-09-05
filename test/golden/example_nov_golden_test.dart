import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/schema/migration/schema_migration.dart';
import 'package:novident_project_manager/src/schema/registry.dart';

/// The golden fixture — a real `.nov` project.
final Directory _project = Directory('assets/example.nov');

String _read(String relativePath) =>
    File('${_project.path}/$relativePath').readAsStringSync();

Map<String, dynamic> _json(String relativePath) =>
    jsonDecode(_read(relativePath)) as Map<String, dynamic>;

List<String> _filesIn(String relativeDir) {
  final Directory dir = Directory('${_project.path}/$relativeDir');
  if (!dir.existsSync()) return const <String>[];
  return dir
      .listSync()
      .whereType<File>()
      .map((File f) => f.path.split('/').last)
      .toList();
}

/// Decodes [raw] through the registry binding of [role] (dynamic dispatch —
/// the codec is typed, the harness is not).
dynamic _decode(String role, String raw) {
  return switch (role) {
    'metadata' => SchemaRegistry.metadata.decode(raw),
    'backup' => SchemaRegistry.backup.decode(raw),
    'binder' => SchemaRegistry.binder.decode(raw),
    'sections' => SchemaRegistry.sections.decode(raw),
    'icon' => SchemaRegistry.icon.decode(raw),
    'corkboard' => SchemaRegistry.corkboard.decode(raw),
    'target' => SchemaRegistry.target.decode(raw),
    'layouts' => SchemaRegistry.layouts.decode(raw),
    'formats' => SchemaRegistry.formats.decode(raw),
    'exports' => SchemaRegistry.exports.decode(raw),
    'sessions' => SchemaRegistry.sessions.decode(raw),
    _ => throw ArgumentError.value(role, 'role'),
  };
}

String _encode(String role, dynamic model) {
  return switch (role) {
    'metadata' => SchemaRegistry.metadata.encode(model),
    'backup' => SchemaRegistry.backup.encode(model),
    'binder' => SchemaRegistry.binder.encode(model),
    'sections' => SchemaRegistry.sections.encode(model),
    'icon' => SchemaRegistry.icon.encode(model),
    'corkboard' => SchemaRegistry.corkboard.encode(model),
    'target' => SchemaRegistry.target.encode(model),
    'layouts' => SchemaRegistry.layouts.encode(model),
    'formats' => SchemaRegistry.formats.encode(model),
    'exports' => SchemaRegistry.exports.encode(model),
    'sessions' => SchemaRegistry.sessions.encode(model),
    _ => throw ArgumentError.value(role, 'role'),
  };
}

/// Asserts decode → encode → decode → encode stabilizes (fixpoint): from the
/// second cycle on the JSON tree is identical. Derived files (binder lookup,
/// format layout ids) converge after the first cycle instead of round-tripping
/// their on-disk form verbatim.
void _expectIdempotent(String role, String raw) {
  final dynamic first = _decode(role, raw);
  final String enc1 = _encode(role, first);
  final dynamic second = _decode(role, enc1);
  final String enc2 = _encode(role, second);
  expect(
    jsonDecode(enc2),
    jsonDecode(enc1),
    reason: '$role is not idempotent (decode → encode → decode → encode)',
  );
}

/// Asserts the model reproduces the on-disk JSON tree verbatim (canonical
/// owner files).
void _expectCanonical(String role, String relativePath) {
  final Map<String, dynamic> original = _json(relativePath);
  final String encoded = _encode(role, _decode(role, _read(relativePath)));
  expect(
    jsonDecode(encoded),
    original,
    reason: '$role does not reproduce $relativePath verbatim',
  );
}

void main() {
  group('structure', () {
    test('every required file exists and parses', () {
      for (final String file in SchemaRegistry.requiredFiles) {
        final File f = File('${_project.path}/$file');
        expect(f.existsSync(), isTrue, reason: 'missing $file');
        expect(() => _json(file), returnsNormally, reason: 'invalid $file');
      }
    });

    test('migrations are a no-op on every v1 file', () {
      final SchemaMigrator migrator = SchemaMigrator.current();
      final List<String> files = <String>[
        ...SchemaRegistry.requiredFiles,
        ...SchemaRegistry.engineManagedFiles,
      ];
      for (final String file in files) {
        final Map<String, dynamic> migrated = migrator.migrateMap(_json(file));
        expect(migrated, _json(file), reason: 'migration changed $file');
      }
    });
  });

  group('top-level schema files', () {
    test('decode without throwing and are idempotent', () {
      for (final MapEntry<String, String> entry
          in SchemaRegistry.topLevelPaths.entries) {
        final String raw = _read(entry.value);
        expect(() => _decode(entry.key, raw), returnsNormally,
            reason: 'cannot decode ${entry.value}');
        // The binder is intentionally excluded from idempotency: it carries
        // derived/volatile fields (recomputed lookup, trashed_at written at
        // encode time).
        if (entry.key != 'binder') {
          _expectIdempotent(entry.key, raw);
        }
      }
    });

    test('canonical owners reproduce their file verbatim', () {
      _expectCanonical('metadata', 'files/metadata.json');
      _expectCanonical('sections', 'indexation/sections.index.json');
      _expectCanonical('icon', 'indexation/icon.index.json');
      _expectCanonical('corkboard', 'indexation/corkboard.index.json');
      _expectCanonical('target', 'indexation/target.index.json');
      _expectCanonical('backup', 'files/backup.json');
      for (final String file in _filesIn('layouts')) {
        _expectCanonical('layouts', 'layouts/$file');
      }
    });
  });

  group('collections', () {
    test('every item decodes and is idempotent', () {
      final Map<String, String> roles = <String, String>{
        'layouts': 'layouts',
        'formats': 'compiler/formats',
        'exports': 'compiler/exports',
        'sessions': 'history',
      };
      roles.forEach((String role, String dir) {
        for (final String file in _filesIn(dir)) {
          final String raw = _read('$dir/$file');
          expect(() => _decode(role, raw), returnsNormally,
              reason: 'cannot decode $dir/$file');
          _expectIdempotent(role, raw);
        }
      });
    });

    test('exports and sessions reproduce their file verbatim', () {
      for (final String file in _filesIn('compiler/exports')) {
        _expectCanonical('exports', 'compiler/exports/$file');
      }
      for (final String file in _filesIn('history')) {
        _expectCanonical('sessions', 'history/$file');
      }
    });
  });
}
