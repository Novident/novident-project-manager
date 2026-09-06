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
          .map(
            (p) => Replacement.fromJson(
              p as Map<String, dynamic>,
            ),
          )
          .toSet(),
    );
  }
}

/// A single find-and-replace pattern used during compilation.
///
/// The pattern replaces [find] with [replace] while the document is
/// compiled. It can be disabled or treated as a regular expression; matching
/// is case-sensitive by default.
class Replacement {
  /// Text (or, when [isRegexp], pattern) to look for.
  final String find;

  /// Text that replaces every match.
  final String replace;

  /// Whether the pattern is active (disabled patterns are ignored).
  final bool enabled;

  /// Whether [find] is interpreted as a regular expression.
  final bool isRegexp;

  /// Whether the match respects letter case.
  final bool caseSensitive;

  /// Builds a replacement with the given values.
  Replacement({
    required this.find,
    required this.replace,
    this.isRegexp = false,
    this.caseSensitive = true,
    this.enabled = true,
  });

  Replacement.disabled({
    this.find = '',
    this.replace = '',
    this.isRegexp = false,
    this.caseSensitive = true,
    this.enabled = false,
  });

  /// Compiled regular expression of [find], or `null` when [isRegexp] is
  /// false.
  RegExp? get regexp => !isRegexp
      ? null
      : RegExp(
          find,
          caseSensitive: caseSensitive,
        );

  /// Serializes the pattern to its on-disk JSON shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'find': find,
        'replace': replace,
        'enabled': enabled,
        'is_regexp': isRegexp,
        'case_sensitive': caseSensitive,
      };

  /// Parses the pattern from its on-disk JSON shape (tolerant of missing
  /// fields).
  factory Replacement.fromJson(Map<String, dynamic> json) => Replacement(
        find: json['find'] as String? ?? '',
        replace: json['replace'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
        isRegexp: json['is_regexp'] as bool? ?? false,
        caseSensitive: json['case_sensitive'] as bool? ?? true,
      );
}
