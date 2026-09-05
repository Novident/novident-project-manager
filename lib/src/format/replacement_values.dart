/// The replacement patterns of a [Format].
///
/// Serialized under the `patterns` key of the format's `replacements` block.
class ReplacementsValues {
  /// The set of replacement patterns, in no particular order.
  final Set<Replacement> replacements;

  /// Builds the collection with the given patterns.
  ReplacementsValues({
    required this.replacements,
  });

  /// Serializes the collection to the on-disk JSON shape
  /// (`{ "patterns": […] }`).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'patterns': replacements.map((r) => r.toJson()).toList(),
      };

  /// Parses the collection from its on-disk JSON shape; a missing `patterns`
  /// list yields an empty set.
  factory ReplacementsValues.fromJson(Map<String, dynamic> json) {
    return ReplacementsValues(
      replacements: (json['patterns'] as List? ?? const <dynamic>[])
          .map((p) => Replacement.fromJson(p as Map<String, dynamic>))
          .toSet(),
    );
  }
}

/// A single find-and-replace pattern used during compilation.
///
/// The pattern replaces [matchCase] with [replacement] while the document is
/// compiled. It can be disabled or treated as a regular expression; matching
/// is case-sensitive by default.
class Replacement {
  /// Text (or, when [isRegexp], pattern) to look for.
  final String matchCase;

  /// Text that replaces every match.
  final String replacement;

  /// Whether the pattern is active (disabled patterns are ignored).
  final bool enabled;

  /// Whether [matchCase] is interpreted as a regular expression.
  final bool isRegexp;

  /// Whether the match respects letter case.
  final bool caseSensitive;

  /// Builds a replacement with the given values.
  Replacement({
    this.matchCase = '',
    this.replacement = '',
    this.enabled = false,
    this.isRegexp = false,
    this.caseSensitive = true,
  });

  /// Compiled regular expression of [matchCase], or `null` when [isRegexp] is
  /// false.
  RegExp? get regexp => !isRegexp
      ? null
      : RegExp(
          matchCase,
          caseSensitive: caseSensitive,
        );

  /// Serializes the pattern to its on-disk JSON shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'match_case': matchCase,
        'replacement': replacement,
        'enabled': enabled,
        'is_regexp': isRegexp,
        'case_sensitive': caseSensitive,
      };

  /// Parses the pattern from its on-disk JSON shape (tolerant of missing
  /// fields).
  factory Replacement.fromJson(Map<String, dynamic> json) => Replacement(
        matchCase: json['match_case'] as String? ?? '',
        replacement: json['replacement'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
        isRegexp: json['is_regexp'] as bool? ?? false,
        caseSensitive: json['case_sensitive'] as bool? ?? true,
      );
}
