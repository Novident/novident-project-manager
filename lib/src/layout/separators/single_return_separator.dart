part of '../separators/layout_separator.dart';

/// A separator that writes nothing, letting the next document continue
/// together with the previous content.
class SingleReturnSeparatorStrategy extends LayoutSeparator {
  const SingleReturnSeparatorStrategy._();

  /// Shared instance of the single-return separator.
  static SingleReturnSeparatorStrategy get instance => _instance == null
      ? _instance = SingleReturnSeparatorStrategy._()
      : _instance!;

  static SingleReturnSeparatorStrategy? _instance;

  /// Writes an empty string as the separator.
  @override
  String buildSeparator() {
    return '';
  }

  /// This separator does not force a page break.
  @override
  bool get breakAfterUse => false;

  /// Stable identifier of the single-return separator.
  @override
  String get id => '2';

  @override
  bool operator ==(covariant SingleReturnSeparatorStrategy other) {
    if (identical(this, other)) return true;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
