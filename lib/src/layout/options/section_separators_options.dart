import 'dart:convert';

import '../separators/layout_separator.dart';

/// Separator behavior of a layout: which [LayoutSeparator] is written before,
/// between and after sections, plus two tuning flags.
class SeparatorOptions {
  /// Separator written before each section.
  final LayoutSeparator separateBeforeSection;

  /// Separator written between sections.
  final LayoutSeparator separatorBetweenSection;

  /// Separator written after the last section.
  final LayoutSeparator separatorAfterSection;

  /// Whether the section's own "separator after" setting overrides this
  /// layout's [separatorAfterSection].
  final bool overrideSeparatorAfter;

  /// Whether blank lines that only carry styles are ignored when separating
  /// sections.
  final bool ignoreBlankLinesWithStyles;

  /// Builds separator options with explicit values.
  SeparatorOptions({
    required this.separateBeforeSection,
    required this.separatorBetweenSection,
    required this.overrideSeparatorAfter,
    required this.ignoreBlankLinesWithStyles,
    required this.separatorAfterSection,
  });

  /// Defaults to the single-return separator everywhere, with overrides
  /// enabled and styled blank lines ignored.
  factory SeparatorOptions.common({
    LayoutSeparator? beforeSection,
    LayoutSeparator? betweenSection,
    LayoutSeparator? afterSection,
    bool overrideSeparatorAfter = true,
  }) {
    return SeparatorOptions(
      separateBeforeSection:
          beforeSection ?? SingleReturnSeparatorStrategy.instance,
      separatorBetweenSection:
          betweenSection ?? SingleReturnSeparatorStrategy.instance,
      separatorAfterSection:
          afterSection ?? SingleReturnSeparatorStrategy.instance,
      overrideSeparatorAfter: overrideSeparatorAfter,
      ignoreBlankLinesWithStyles: true,
    );
  }

  /// Returns a copy with the given values replaced.
  SeparatorOptions copyWith({
    LayoutSeparator? separateBeforeSection,
    LayoutSeparator? separatorBetweenSection,
    bool? overrideSeparatorAfter,
    LayoutSeparator? separatorAfterSection,
    bool? ignoreBlankLinesWithStyles,
  }) {
    return SeparatorOptions(
      separateBeforeSection:
          separateBeforeSection ?? this.separateBeforeSection,
      separatorBetweenSection:
          separatorBetweenSection ?? this.separatorBetweenSection,
      overrideSeparatorAfter:
          overrideSeparatorAfter ?? this.overrideSeparatorAfter,
      separatorAfterSection:
          separatorAfterSection ?? this.separatorAfterSection,
      ignoreBlankLinesWithStyles:
          ignoreBlankLinesWithStyles ?? this.ignoreBlankLinesWithStyles,
    );
  }

  /// Serializes the options to their on-disk JSON map (`before`/`between`/
  /// `after_section` carry the separator objects).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'before': separateBeforeSection.toJson(),
      'between': separatorBetweenSection.toJson(),
      'after_section': separatorAfterSection.toJson(),
      'override_separator_after': overrideSeparatorAfter,
      'ignore_blank_lines_with_styles': ignoreBlankLinesWithStyles,
    };
  }

  /// Parses the options from their on-disk JSON map; missing or malformed
  /// separators fall back to the [SeparatorOptions.common] defaults.
  factory SeparatorOptions.fromMap(Map<String, dynamic> map) {
    final SeparatorOptions defaults = SeparatorOptions.common();
    LayoutSeparator read(String key, LayoutSeparator fallback) {
      final value = map[key];
      return value is Map<String, dynamic>
          ? LayoutSeparator.fromJson(value) ?? fallback
          : fallback;
    }

    return SeparatorOptions(
      separateBeforeSection: read('before', defaults.separateBeforeSection),
      separatorBetweenSection:
          read('between', defaults.separatorBetweenSection),
      separatorAfterSection:
          read('after_section', defaults.separatorAfterSection),
      overrideSeparatorAfter: map['override_separator_after'] as bool? ?? true,
      ignoreBlankLinesWithStyles:
          map['ignore_blank_lines_with_styles'] as bool? ?? true,
    );
  }

  /// Serializes the options to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses the options from their JSON string.
  factory SeparatorOptions.fromJson(String source) => SeparatorOptions.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  bool operator ==(covariant SeparatorOptions other) {
    if (identical(this, other)) return true;

    return other.separateBeforeSection == separateBeforeSection &&
        other.separatorBetweenSection == separatorBetweenSection &&
        other.separatorAfterSection == separatorAfterSection &&
        other.overrideSeparatorAfter == overrideSeparatorAfter &&
        other.ignoreBlankLinesWithStyles == ignoreBlankLinesWithStyles;
  }

  @override
  int get hashCode {
    return separateBeforeSection.hashCode ^
        separatorBetweenSection.hashCode ^
        separatorAfterSection.hashCode ^
        overrideSeparatorAfter.hashCode ^
        ignoreBlankLinesWithStyles.hashCode;
  }
}
