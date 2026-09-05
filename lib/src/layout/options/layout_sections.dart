import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'section_attributes.dart';

/// Configuration of one layout part (title, metadata, synopsis, notes or
/// text): whether it is shown, whether it overrides editor formatting, its
/// heading and its [SectionAttributes].
///
/// Pure data: converting a section into AST content is done externally by
/// `LayoutSectionBuilder`.
@immutable
class LayoutSection extends Equatable {
  /// Whether this section is rendered during compilation.
  final bool show;

  /// Whether the section's own attributes override the text-section
  /// attributes applied by the editor.
  final bool overrideTextSection;

  /// Whether the section's alignment overrides the editor alignment.
  final bool overrideAlign;

  /// Heading written above the section content (when applicable).
  final String title;

  /// Styling applied to the section.
  final SectionAttributes attributes;

  /// Builds a section configuration.
  const LayoutSection({
    required this.show,
    required this.title,
    required this.attributes,
    this.overrideTextSection = false,
    this.overrideAlign = false,
  });

  /// Returns a copy with the given values replaced.
  LayoutSection copyWith({
    bool? show,
    bool? overrideTextSection,
    bool? overrideAlign,
    String? title,
    SectionAttributes? attributes,
  }) {
    return LayoutSection(
      show: show ?? this.show,
      overrideAlign: overrideAlign ?? this.overrideAlign,
      overrideTextSection: overrideTextSection ?? this.overrideTextSection,
      title: title ?? this.title,
      attributes: attributes ?? this.attributes,
    );
  }

  /// Serializes the section to its on-disk JSON map (snake_case keys).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'show': show,
      'override_align': overrideAlign,
      'override_text_section': overrideTextSection,
      'title': title,
      'attributes': attributes.toMap(),
    };
  }

  /// Parses the section from its on-disk JSON map (tolerant of missing
  /// fields).
  factory LayoutSection.fromMap(Map<String, dynamic> map) {
    return LayoutSection(
      show: map['show'] as bool? ?? false,
      overrideAlign: map['override_align'] as bool? ?? false,
      overrideTextSection: map['override_text_section'] as bool? ?? false,
      title: map['title'] as String? ?? '',
      attributes: map['attributes'] is Map<String, dynamic>
          ? SectionAttributes.fromMap(map['attributes'] as Map<String, dynamic>)
          : SectionAttributes.common(),
    );
  }

  /// Serializes the section to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses the section from its JSON string.
  factory LayoutSection.fromJson(String source) => LayoutSection.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  List<Object> get props {
    return [
      show,
      overrideTextSection,
      overrideAlign,
      title,
      attributes,
    ];
  }
}
