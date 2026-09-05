part of '../separators/layout_separator.dart';

/// A separator that writes a single new line, breaking the current line so the
/// next content starts on a fresh one.
@immutable
class EmptyLineSeparatorStrategy extends LayoutSeparator {
  const EmptyLineSeparatorStrategy._();

  /// Shared instance of the empty-line separator.
  static EmptyLineSeparatorStrategy get instance => _instance == null
      ? _instance = EmptyLineSeparatorStrategy._()
      : _instance!;

  static EmptyLineSeparatorStrategy? _instance;

  /// Writes a `\n` as the separator.
  @override
  String buildSeparator() {
    return '\n';
  }

  /// This separator does not force a page break.
  @override
  bool get breakAfterUse => false;

  /// Stable identifier of the empty-line separator.
  @override
  String get id => '1';

  @override
  bool operator ==(covariant EmptyLineSeparatorStrategy other) {
    if (identical(this, other)) return true;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
