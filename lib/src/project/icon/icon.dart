import 'dart:convert';

import 'package:novident_project_manager/src/schema/registry.dart';

/// Icon rules (`indexation/icon.index.json`).
///
/// Top-level keys are `schema_version`, `defaults` (per node type) and — for
/// the serialized form — per-node-id overrides that are flattened at the top
/// level. The codec splits those overrides into their own map on read and
/// re-flattens them on write.
class IconIndex {
  final int? schemaVersion;
  final Map<String, IconRule> defaults;
  final Map<String, IconRule> overrides;

  const IconIndex({
    this.schemaVersion = kCurrentSchemaVersion,
    this.defaults = const <String, IconRule>{},
    this.overrides = const <String, IconRule>{},
  });

  factory IconIndex.fromJson(Map<String, dynamic> json) {
    final defaults = <String, IconRule>{};
    final overrides = <String, IconRule>{};
    final rawDefaults = json['defaults'];
    if (rawDefaults is Map<String, dynamic>) {
      rawDefaults.forEach((String key, dynamic value) {
        if (value is Map<String, dynamic>) {
          defaults[key] = IconRule.fromJson(value);
        }
      });
    }
    // Any other top-level key is a flattened per-node override.
    json.forEach((String key, dynamic value) {
      if (key == 'schema_version' || key == 'defaults') return;
      if (value is Map<String, dynamic>) {
        overrides[key] = IconRule.fromJson(value);
      }
    });
    return IconIndex(
      schemaVersion: json['schema_version'] as int?,
      defaults: defaults,
      overrides: overrides,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (schemaVersion != null) 'schema_version': schemaVersion,
        'defaults': defaults.map(
            (String key, IconRule rule) => MapEntry(key, rule.toJson())),
        // Overrides are flattened at the top level on disk.
        ...overrides.map(
            (String key, IconRule rule) => MapEntry(key, rule.toJson())),
      };

  String toJsonString() => json.encode(toJson());

  factory IconIndex.fromJsonString(String source) =>
      IconIndex.fromJson(json.decode(source) as Map<String, dynamic>);
}

/// The icon for a node type (in `defaults`) or for a single node id (in
/// `overrides`). `variations` maps an expression (`exp:`/`state:`, see the
/// format spec §9) to the icon name that replaces the base one when true.
class IconRule {
  final String icon;
  final String type;
  final Map<String, String> variations;
  final String? path;

  const IconRule({
    this.icon = '',
    this.type = '',
    this.variations = const <String, String>{},
    this.path,
  });

  factory IconRule.fromJson(Map<String, dynamic> json) {
    final rawVariations = json['variations'];
    return IconRule(
      icon: json['icon'] as String? ?? '',
      type: json['type'] as String? ?? '',
      variations: rawVariations is Map<String, dynamic>
          ? rawVariations.map((String key, dynamic value) =>
              MapEntry(key, value as String))
          : const <String, String>{},
      path: json['path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'icon': icon,
        'type': type,
        if (variations.isNotEmpty) 'variations': variations,
        'path': path,
      };
}
