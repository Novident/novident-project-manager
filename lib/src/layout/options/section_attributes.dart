import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:novident_editor_styles/novident_editor_styles.dart';

import '../../extensions/string_extension.dart';

/// Text/block attributes of a layout section.
///
/// These describe inline formatting (bold, italic, underline, font size, …)
/// plus block-level alignment/indentation used when a section is compiled into
/// editor content.
class SectionAttributes {
  /// Whether the text is bold.
  final bool bold;

  /// Whether the text is italic.
  final bool italic;

  /// Whether the text is underlined.
  final bool underline;

  /// Font size of the text.
  final double fontSize;

  /// Whether the text has a strikethrough.
  final bool strikethrough;

  /// Line height multiplier of the text.
  final double lineHeight;

  /// Font family of the text.
  final String fontFamily;

  /// Text color (hex string without the leading `#`), when set.
  final String? color;

  /// Hyperlink target, when set.
  final String? link;

  /// Block heading level, when the section acts as a heading.
  final int? headerLevel;

  /// Block alignment: `left`, `right`, `center` or `justify`.
  final String align;

  /// Block indentation level (`-1` means "not set"; otherwise 1–4).
  final int indent;

  /// Builds attributes; values must satisfy the documented constraints.
  SectionAttributes({
    required this.fontSize,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.lineHeight,
    required this.strikethrough,
    required this.align,
    required this.headerLevel,
    required this.fontFamily,
    this.color,
    this.link,
    this.indent = -1,
  })  : assert(lineHeight <= 3.0 && lineHeight >= 1.0,
            'lineHeight must be between 1.0 and 3.0'),
        assert(indent == -1 || indent > 0 && indent <= 4,
            'Invalid indent $indent'),
        assert(
          align.equals('left') ||
              align.equals('right') ||
              align.equals('center') ||
              align.equals('justify'),
          'Alignment: $align is invalid. Only '
          'supported options: [left, right, center, and justify]',
        );

  /// Builds neutral attributes (12pt, left-aligned, regular) with the given
  /// overrides.
  ///
  /// `automaticIndent`, `rgbBackground` and `image` are accepted for API
  /// compatibility and currently unused by the model.
  factory SectionAttributes.common({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? automaticIndent,
    int? headerLevel,
    String? color,
    String? rgbBackground,
    String? fontFamily,
    String? align,
    String? image,
    double? lineHeight,
    double? fontSize,
  }) {
    return SectionAttributes(
      align: align ?? 'left',
      bold: bold ?? false,
      italic: italic ?? false,
      strikethrough: false,
      indent: -1,
      link: null,
      headerLevel: headerLevel ?? 0,
      lineHeight: lineHeight ?? 1.0,
      fontFamily: fontFamily ?? getDefaultFont(),
      fontSize: fontSize ?? 12,
      color: color,
      underline: underline ?? false,
    );
  }

  /// Returns a copy with the given values replaced.
  SectionAttributes copyWith({
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? automaticIndent,
    String? fontFamily,
    String? color,
    String? image,
    double? lineHeight,
    bool? strikethrough,
    String? link,
    String? align,
    int? indent,
    int? headerLevel,
  }) {
    return SectionAttributes(
      fontSize: fontSize ?? this.fontSize,
      strikethrough: strikethrough ?? this.strikethrough,
      indent: indent ?? this.indent,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      lineHeight: lineHeight ?? this.lineHeight,
      underline: underline ?? this.underline,
      fontFamily: fontFamily ?? this.fontFamily,
      color: color ?? this.color,
      align: align ?? this.align,
      headerLevel: headerLevel ?? this.headerLevel,
    );
  }

  /// Converts the attributes into an editor style definition for compilation.
  ///
  /// [fontFamily] overrides the configured family when given.
  NovidentStyleDefinition toStyle({String? fontFamily}) {
    return NovidentStyleDefinition(
        id: '__compiled__',
        name: 'compiled',
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        fontFamily: fontFamily ?? this.fontFamily,
        textColor: color != null ? Color(int.parse('#$color')) : null,
        alignment: _align(),
        spacing: NovidentStyleSpacing(lineHeight: lineHeight));
  }

  TextAlign _align() {
    if (align == 'center') {
      return TextAlign.center;
    }
    if (align == 'right') {
      return TextAlign.end;
    }
    if (align == 'justify') {
      return TextAlign.justify;
    }
    return TextAlign.start;
  }

  /// Serializes the attributes to their on-disk JSON map (snake_case keys).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'font_size': fontSize,
      'bold': bold,
      'italic': italic,
      'underline': underline,
      'line_height': lineHeight,
      'strikethrough': strikethrough,
      'indent': indent,
      'font_family': fontFamily,
      'color': color,
      'link': link,
      'align': align,
      'header_level': headerLevel,
    };
  }

  /// Parses the attributes from their on-disk JSON map (tolerant of missing
  /// fields).
  factory SectionAttributes.fromMap(Map<String, dynamic> map) {
    return SectionAttributes(
      fontSize: (map['font_size'] as num?)?.toDouble() ?? 12,
      strikethrough: map['strikethrough'] as bool? ?? false,
      bold: map['bold'] as bool? ?? false,
      italic: map['italic'] as bool? ?? false,
      link: map['link'] as String?,
      indent: map['indent'] as int? ?? -1,
      underline: map['underline'] as bool? ?? false,
      lineHeight: (map['line_height'] as num?)?.toDouble() ?? 1.0,
      fontFamily: map['font_family'] as String? ?? getDefaultFont(),
      color: map['color'] as String?,
      align: map['align'] as String? ?? 'left',
      headerLevel: map['header_level'] is int
          ? map['header_level'] as int?
          : int.tryParse(map['header_level'] as String? ?? ''),
    );
  }

  /// Serializes the attributes to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses the attributes from their JSON string.
  factory SectionAttributes.fromJson(String source) =>
      SectionAttributes.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  String toString() {
    return 'SectionAttributes('
        'lineHeight: $lineHeight, '
        'fontSize: $fontSize, '
        'bold: $bold, '
        'italic: $italic, '
        'underline: $underline, '
        'fontFamily: $fontFamily, '
        'color: $color, '
        'align: $align, '
        'headerLevel: $headerLevel'
        ')';
  }
}
