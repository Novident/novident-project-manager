import 'dart:convert';

/// Indentation settings of a layout's `settings` block.
///
/// All values default to `false`: applying the settings is opt-in, indentation
/// is not applied automatically, and the first paragraph after a section
/// heading keeps its default indentation unless configured otherwise.
class LayoutSettingsIndent {
  /// Whether the layout changes are applied to already-written content.
  final bool applyChanges;

  /// Whether paragraphs are automatically indented.
  final bool indentParagraph;

  /// Whether the first paragraph after the title is also indented (only
  /// meaningful when [indentParagraph] is true).
  final bool indentJustAfterFirstParagraph;

  /// Builds indentation settings with explicit values.
  LayoutSettingsIndent({
    required this.applyChanges,
    required this.indentParagraph,
    required this.indentJustAfterFirstParagraph,
  });

  /// Defaults: nothing is applied, nothing is indented.
  factory LayoutSettingsIndent.common() {
    return LayoutSettingsIndent(
      applyChanges: false,
      indentParagraph: false,
      indentJustAfterFirstParagraph: false,
    );
  }

  /// Returns a copy with the given values replaced.
  LayoutSettingsIndent copyWith({
    bool? applyChanges,
    bool? indentParagraph,
    bool? indentAfterFirst,
  }) {
    return LayoutSettingsIndent(
      applyChanges: applyChanges ?? this.applyChanges,
      indentParagraph: indentParagraph ?? this.indentParagraph,
      indentJustAfterFirstParagraph:
          indentAfterFirst ?? indentJustAfterFirstParagraph,
    );
  }

  /// Serializes the settings to their on-disk JSON map (snake_case keys).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'apply_changes': applyChanges,
      'indent_paragraph': indentParagraph,
      'indent_just_after_first_paragraph': indentJustAfterFirstParagraph,
    };
  }

  /// Parses the settings from their on-disk JSON map (tolerant of missing
  /// fields).
  factory LayoutSettingsIndent.fromMap(Map<String, dynamic> map) {
    return LayoutSettingsIndent(
      applyChanges: map['apply_changes'] as bool? ?? false,
      indentParagraph: map['indent_paragraph'] as bool? ?? false,
      indentJustAfterFirstParagraph:
          map['indent_just_after_first_paragraph'] as bool? ?? false,
    );
  }

  /// Serializes the settings to a JSON string.
  String toJson() => json.encode(
        toMap(),
      );

  /// Parses the settings from their JSON string.
  factory LayoutSettingsIndent.fromJson(String source) =>
      LayoutSettingsIndent.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  String toString() {
    return 'LayoutSettingsIndent('
        'applyChanges: $applyChanges, '
        'indentParagraph: $indentParagraph, '
        'indentJustAfterFirstParagraph: $indentJustAfterFirstParagraph'
        ')';
  }

  @override
  bool operator ==(covariant LayoutSettingsIndent other) {
    if (identical(this, other)) return true;

    return other.applyChanges == applyChanges &&
        other.indentParagraph == indentParagraph &&
        other.indentJustAfterFirstParagraph == indentJustAfterFirstParagraph;
  }

  @override
  int get hashCode =>
      applyChanges.hashCode ^
      indentParagraph.hashCode ^
      indentJustAfterFirstParagraph.hashCode;
}
