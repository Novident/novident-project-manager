import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/icon/icon.dart';

void main() {
  final Map<String, dynamic> fixture = jsonDecode('''
{
  "schema_version": 1,
  "defaults": {
    "file": {
      "icon": "file",
      "type": "internal",
      "variations": {
        "exp:empty": "empty_file",
        "state:trashed": "opaque-file"
      },
      "path": null
    },
    "templatesSheet": {
      "icon": "template",
      "type": "internal",
      "path": null
    }
  },
  "a1b2c3d4-e5f6-7890-abcd-ef1234567890": {
    "icon": "manuscript",
    "type": "internal",
    "path": null
  },
  "c9d0e1f2-a3b4-5678-cdef-789012345678": {
    "icon": "characters",
    "type": "internal",
    "path": null
  }
}
''') as Map<String, dynamic>;

  test('IconIndex separates defaults from flattened per-node overrides', () {
    final icons = IconIndex.fromJson(fixture);

    expect(icons.schemaVersion, 1);
    expect(
        icons.defaults.keys, containsAll(<String>['file', 'templatesSheet']));
    expect(
        icons.overrides.keys,
        containsAll(<String>[
          'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          'c9d0e1f2-a3b4-5678-cdef-789012345678',
        ]));

    final file = icons.defaults['file']!;
    expect(file.icon, 'file');
    expect(file.variations['exp:empty'], 'empty_file');
    expect(file.path, isNull);

    expect(icons.overrides['c9d0e1f2-a3b4-5678-cdef-789012345678']!.icon,
        'characters');
  });

  test('IconIndex roundtrips and re-flattens overrides at the top level', () {
    final icons = IconIndex.fromJson(fixture);
    final map = json.decode(icons.toJsonString()) as Map<String, dynamic>;

    expect(map['defaults'], isNotNull);
    // Overrides live at the top level, next to defaults.
    expect(map['a1b2c3d4-e5f6-7890-abcd-ef1234567890'], isNotNull);
    expect(map['c9d0e1f2-a3b4-5678-cdef-789012345678'], isNotNull);
    expect(map.containsKey('overrides'), isFalse);

    expect(map, fixture);
  });

  test('IconRule omits variations when absent and always carries path', () {
    final rule = const IconRule(icon: 'template', type: 'internal').toJson();
    expect(rule.containsKey('variations'), isFalse);
    expect(rule.containsKey('path'), isTrue);
    expect(rule['path'], isNull);
  });

  test('IconIndex.fromJson tolerates missing fields', () {
    final icons = IconIndex.fromJson(const <String, dynamic>{});
    expect(icons.schemaVersion, isNull);
    expect(icons.defaults, isEmpty);
    expect(icons.overrides, isEmpty);
  });
}
