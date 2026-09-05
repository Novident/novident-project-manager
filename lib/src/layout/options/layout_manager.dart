import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'layout_sections.dart';
import 'section_attributes.dart';

/// Holds the five [LayoutSection]s of a layout: title, metadata, synopsis,
/// notes and text. Each section decides whether it is shown and how it is
/// styled during compilation.
@immutable
class LayoutSectionManager extends Equatable {
  /// Configuration of the title section.
  final LayoutSection titleSection;

  /// Configuration of the metadata section.
  final LayoutSection metadataSection;

  /// Configuration of the synopsis section.
  final LayoutSection synopsisSection;

  /// Configuration of the notes section.
  final LayoutSection notesSection;

  /// Configuration of the body text section.
  final LayoutSection textSection;

  /// Builds the manager with one section configuration per part.
  const LayoutSectionManager({
    required this.titleSection,
    required this.metadataSection,
    required this.synopsisSection,
    required this.notesSection,
    required this.textSection,
  });

  /// Serializes the manager to its on-disk JSON map (snake_case keys).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title_section': titleSection.toMap(),
      'metadata_section': metadataSection.toMap(),
      'synopsis_section': synopsisSection.toMap(),
      'notes_section': notesSection.toMap(),
      'text_section': textSection.toMap(),
    };
  }

  /// Decodes a section entry; missing or malformed entries fall back to a
  /// hidden, empty section.
  static LayoutSection _read(String key, Map<String, dynamic> map) {
    final value = map[key];
    if (value is Map<String, dynamic>) {
      return LayoutSection.fromMap(value);
    }
    return LayoutSection(
      show: false,
      title: '__Unknown__',
      attributes: SectionAttributes.common(),
    );
  }

  /// Parses the manager from its on-disk JSON map (tolerant of missing
  /// sections).
  factory LayoutSectionManager.fromMap(Map<String, dynamic> map) {
    return LayoutSectionManager(
      titleSection: _read('title_section', map),
      metadataSection: _read('metadata_section', map),
      synopsisSection: _read('synopsis_section', map),
      notesSection: _read('notes_section', map),
      textSection: _read('text_section', map),
    );
  }

  /// Serializes the manager to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses the manager from its JSON string.
  factory LayoutSectionManager.fromJson(String source) =>
      LayoutSectionManager.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Returns a copy with the given sections replaced.
  LayoutSectionManager copyWith({
    LayoutSection? titleSection,
    LayoutSection? metadataSection,
    LayoutSection? synopsisSection,
    LayoutSection? notesSection,
    LayoutSection? textSection,
  }) {
    return LayoutSectionManager(
      titleSection: titleSection ?? this.titleSection,
      metadataSection: metadataSection ?? this.metadataSection,
      synopsisSection: synopsisSection ?? this.synopsisSection,
      notesSection: notesSection ?? this.notesSection,
      textSection: textSection ?? this.textSection,
    );
  }

  @override
  List<Object> get props {
    return <Object>[
      titleSection,
      metadataSection,
      synopsisSection,
      notesSection,
      textSection,
    ];
  }

  @override
  bool get stringify => true;
}
