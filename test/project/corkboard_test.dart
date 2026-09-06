import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/corkboard/corkboard.dart';

void main() {
  final Map<String, dynamic> fixture = jsonDecode('''
{
  "schema_version": 1,
  "corkboards": [
    {
      "element_id": "c3d4e5f6-a7b8-9012-cdef-123456789012",
      "element_name": "Chapter 1",
      "element_path": "files/c3d4e5f6-a7b8-9012-cdef-123456789012",
      "values": {
        "freeform": {
          "world": {
            "nodes": [
              {
                "node_id": "d4e5f6a7-b8c9-0123-defa-234567890123",
                "node_name": "The Awakening",
                "x": 120.0,
                "y": 80.0,
                "width": 220.0,
                "height": 300.0
              }
            ]
          },
          "viewport": {
            "offset_x": -50.0,
            "offset_y": -30.0
          },
          "z_index": [
            "d4e5f6a7-b8c9-0123-defa-234567890123"
          ],
          "selected_node_id": "d4e5f6a7-b8c9-0123-defa-234567890123",
          "config": "default_grid_medium"
        },
        "ratio": 0.35,
        "spacing": 16.0
      }
    },
    {
      "element_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "element_name": "Draft",
      "element_path": "files/b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "values": {
        "freeform": null,
        "ratio": 0.25,
        "spacing": 8.0
      }
    }
  ]
}
''') as Map<String, dynamic>;

  test('CorkboardIndex roundtrips the real fixture shape', () {
    final decoded = CorkboardIndex.fromJson(fixture);
    expect(json.decode(decoded.toJsonString()), fixture);
  });

  test('CorkboardIndex reads nested values', () {
    final corkboard = CorkboardIndex.fromJson(fixture).corkboards.first;

    expect(corkboard.elementId, 'c3d4e5f6-a7b8-9012-cdef-123456789012');
    expect(corkboard.values.ratio, 0.35);
    expect(corkboard.values.spacing, 16.0);

    final freeform = corkboard.values.freeform!;
    expect(freeform.world.nodes.single.nodeName, 'The Awakening');
    expect(freeform.world.nodes.single.x, 120.0);
    expect(freeform.viewport.offsetX, -50.0);
    expect(freeform.selectedNodeId, 'd4e5f6a7-b8c9-0123-defa-234567890123');
    expect(freeform.config, 'default_grid_medium');
  });

  test('CorkboardValues.freeform may be null', () {
    final values = CorkboardIndex.fromJson(fixture)
        .corkboards
        .last
        .toJson()['values'] as Map<String, dynamic>;
    expect(values.containsKey('freeform'), isTrue);
    expect(values['freeform'], isNull);
  });

  test('CorkboardIndex.fromJson tolerates missing fields', () {
    final index = CorkboardIndex.fromJson(const <String, dynamic>{});
    expect(index.schemaVersion, isNull);
    expect(index.corkboards, isEmpty);
  });
}
