part of '../separators/layout_separator.dart';

/// A separator that writes user-supplied content.
@immutable
class CustomSeparatorStrategy extends LayoutSeparator {
  /// Builds the custom separator from [content] and the [breakAfter] flag.
  const CustomSeparatorStrategy({
    required this.breakAfter,
    required this.content,
  });

  /// Internal instance used only to read the strategy id (no content).
  @internal
  const CustomSeparatorStrategy.internal()
      : breakAfter = false,
        content = '';

  /// Whether using this separator starts a new page.
  final bool breakAfter;

  /// Literal content written by the separator.
  final String content;

  /// Whether this separator breaks the page.
  @override
  bool get breakAfterUse => breakAfter;

  /// Returns [content] as the written separator.
  @override
  String buildSeparator() {
    return content;
  }

  /// Stable identifier of the custom separator.
  @override
  String get id => '4';

  /// Serializes the separator, adding `content` and the page-break flag.
  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'content': content,
      'break': breakAfter,
    };
  }

  /// Parses a custom separator from its JSON object.
  factory CustomSeparatorStrategy.fromJson(Map<String, dynamic> json) {
    return CustomSeparatorStrategy(
      breakAfter: json['break'] as bool,
      content: json['content'] as String,
    );
  }

  @override
  bool operator ==(covariant CustomSeparatorStrategy other) {
    if (identical(this, other)) return true;
    return id == other.id &&
        content == other.content &&
        breakAfter == other.breakAfter;
  }

  @override
  int get hashCode => id.hashCode ^ content.hashCode ^ breakAfter.hashCode;
}
