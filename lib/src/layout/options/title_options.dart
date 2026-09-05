import 'dart:convert';

import 'package:novident_project_manager/src/layout/options/section_attributes.dart';

/// How the case of a string is transformed.
enum LetterCase {
  /// Every character is uppercased.
  uppercase,

  /// Every word starts with an uppercased character.
  titlecase,

  /// Every character is lowercased.
  lowercase,

  /// The string keeps its original aspect.
  normal,
}

/// Title prefix/suffix options of a layout.
///
/// A title can be decorated with a prefix and a suffix (which may contain
/// keywords such as `<$n>` or an index placeholder), each styled with its own
/// [SectionAttributes] and case rule.
///
/// Pure data: building the prefix/suffix AST paragraphs is done externally by
/// `TitleOptionsBuilder`.
class TitleOptions {
  /// Text written before the title. Only placeholders that index words work
  /// here (`<$n>`, `<$wc>` and similar).
  final String titlePrefix;

  /// Text written after the title.
  final String titleSuffix;

  /// Case applied to [titlePrefix].
  final LetterCase lettercasePrefix;

  /// Case applied to [titleSuffix].
  final LetterCase lettercaseSuffix;

  /// Case applied to the title itself.
  final LetterCase lettercaseTitle;

  /// Attributes of the prefix. They do not apply when [titlePrefix] and
  /// [titleSuffix] are empty.
  final SectionAttributes attrPrefix;

  /// Attributes of the suffix.
  final SectionAttributes attrSuffix;

  /// Legacy plain prefix appended without attributes (kept for compatibility).
  final String? preffix;

  /// Legacy plain suffix appended without attributes (kept for compatibility).
  final String? suffix;

  /// Builds title options.
  TitleOptions({
    required this.titlePrefix,
    required this.titleSuffix,
    required this.attrPrefix,
    required this.attrSuffix,
    required this.lettercasePrefix,
    required this.lettercaseSuffix,
    required this.lettercaseTitle,
    this.preffix,
    this.suffix,
  });

  /// Neutral title options: no prefix/suffix text, normal case everywhere and
  /// default attributes.
  factory TitleOptions.common({String? preffix, String? suffix}) {
    return TitleOptions(
      titlePrefix: preffix ?? "",
      titleSuffix: suffix ?? "",
      lettercasePrefix: LetterCase.normal,
      lettercaseSuffix: LetterCase.normal,
      lettercaseTitle: LetterCase.normal,
      attrPrefix: SectionAttributes.common(),
      attrSuffix: SectionAttributes.common(),
    );
  }

  /// Returns a copy with the given values replaced.
  TitleOptions copyWith({
    String? titlePrefix,
    String? titleSuffix,
    LetterCase? lettercasePreffix,
    LetterCase? lettercaseSuffix,
    LetterCase? lettercaseTitle,
    SectionAttributes? attrPreffix,
    SectionAttributes? attrSuffix,
    String? suffix,
    String? preffix,
  }) {
    return TitleOptions(
      titlePrefix: titlePrefix ?? this.titlePrefix,
      lettercasePrefix: lettercasePreffix ?? lettercasePrefix,
      lettercaseSuffix: lettercaseSuffix ?? this.lettercaseSuffix,
      lettercaseTitle: lettercaseTitle ?? this.lettercaseTitle,
      titleSuffix: titleSuffix ?? this.titleSuffix,
      attrPrefix: attrPreffix ?? attrPrefix,
      attrSuffix: attrSuffix ?? this.attrSuffix,
      suffix: suffix ?? this.suffix,
      preffix: preffix ?? this.preffix,
    );
  }

  /// Serializes the options to their on-disk JSON map (snake_case keys).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'prefix': titlePrefix,
      'suffix': titleSuffix,
      'letter_case_prefix': lettercasePrefix.index,
      'letter_case_suffix': lettercaseSuffix.index,
      'letter_case_title': lettercaseTitle.index,
      'attr_prefix': attrPrefix.toMap(),
      'attr_suffix': attrSuffix.toMap(),
    };
  }

  /// Parses the options from their on-disk JSON map (tolerant of missing
  /// fields).
  factory TitleOptions.fromMap(Map<String, dynamic> map) {
    return TitleOptions(
      titlePrefix: map['prefix'] as String? ?? '',
      titleSuffix: map['suffix'] as String? ?? '',
      lettercasePrefix: _readLetterCase(map['letter_case_prefix']),
      lettercaseSuffix: _readLetterCase(map['letter_case_suffix']),
      lettercaseTitle: _readLetterCase(map['letter_case_title']),
      attrPrefix: map['attr_prefix'] is Map<String, dynamic>
          ? SectionAttributes.fromMap(map['attr_prefix'] as Map<String, dynamic>)
          : SectionAttributes.common(),
      attrSuffix: map['attr_suffix'] is Map<String, dynamic>
          ? SectionAttributes.fromMap(map['attr_suffix'] as Map<String, dynamic>)
          : SectionAttributes.common(),
    );
  }

  /// Reads a letter-case value from its serialized index, falling back to
  /// [LetterCase.normal] for missing or out-of-range values.
  static LetterCase _readLetterCase(Object? value) {
    final int index = value is int ? value : LetterCase.normal.index;
    if (index < 0 || index >= LetterCase.values.length) {
      return LetterCase.normal;
    }
    return LetterCase.values[index];
  }

  /// Serializes the options to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses the options from their JSON string.
  factory TitleOptions.fromJson(String source) => TitleOptions.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  bool operator ==(covariant TitleOptions other) {
    if (identical(this, other)) return true;

    return other.titlePrefix == titlePrefix &&
        other.titleSuffix == titleSuffix &&
        other.lettercasePrefix == lettercasePrefix &&
        other.lettercaseSuffix == lettercaseSuffix &&
        other.lettercaseTitle == lettercaseTitle &&
        other.attrPrefix == attrPrefix &&
        other.attrSuffix == attrSuffix &&
        other.preffix == preffix &&
        other.suffix == suffix;
  }

  @override
  int get hashCode {
    return titlePrefix.hashCode ^
        titleSuffix.hashCode ^
        lettercasePrefix.hashCode ^
        lettercaseSuffix.hashCode ^
        lettercaseTitle.hashCode ^
        attrPrefix.hashCode ^
        attrSuffix.hashCode ^
        preffix.hashCode ^
        suffix.hashCode;
  }
}
