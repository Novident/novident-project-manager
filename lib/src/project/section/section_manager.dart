import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:novident_project_manager/src/project/section/section.dart';
import 'package:novident_project_manager/src/project/section/section_types_configuration.dart';

/// Runtime holder of the project sections: the list of [Section] types plus
/// the depth outline that resolves `structured-based` nodes.
class SectionManager {
  /// The defined section types.
  final List<Section> sections;

  /// Folder/document depth outline.
  final SectionTypeConfigurations config;

  /// Builds the manager.
  SectionManager({
    required this.sections,
    required this.config,
  });

  int get length => sections.length;

  Section? where(bool Function(Section element) onFound) {
    return sections.firstWhereOrNull(onFound);
  }

  void insertAt(Section object, int index) {
    sections.insert(index, object);
  }

  void removeAt(int index) {
    sections.removeAt(index);
  }

  Section elementAt(int index) {
    return sections[index];
  }

  Section? elementAtOrNull(int index) {
    return sections.elementAtOrNull(index);
  }

  /// Returns a copy with the given values replaced.
  SectionManager copyWith({
    List<Section>? sections,
    SectionTypeConfigurations? config,
  }) {
    return SectionManager(
      sections: sections ?? this.sections,
      config: config ?? this.config,
    );
  }

  /// Parses the manager from a JSON map.
  factory SectionManager.fromMap(Map<String, dynamic> map) {
    return SectionManager(
      sections: List<Section>.from(
        (map['sections'] as List).map<Section>(
          (x) => Section.fromMap(x as Map<String, dynamic>),
        ),
      ),
      config: SectionTypeConfigurations.fromMap(
          map['config'] as Map<String, dynamic>),
    );
  }

  /// Serializes the manager to a JSON map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sections': sections.map((Section x) => x.toMap()).toList(),
      'config': config.toMap(),
    };
  }

  /// Serializes the manager to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses the manager from its JSON string.
  factory SectionManager.fromJson(String source) =>
      SectionManager.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(covariant SectionManager other) {
    if (identical(this, other)) return true;

    return config == other.config && listEquals(other.sections, sections);
  }

  @override
  int get hashCode => sections.hashCode ^ config.hashCode;

  @override
  String toString() => 'SectionManager(sections: $sections, config: $config)';
}
