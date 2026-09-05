// ignore_for_file: unused_element, unused_field
import 'package:meta/meta.dart';

import '../../exceptions/unknown_layout_separator_exception.dart';

part 'single_return_separator.dart';
part 'empty_line_separator.dart';
part 'page_break_separator.dart';
part 'custom_separator.dart';

/// A separator strategy inserted between pieces of compiled content.
///
/// Implementations decide what is written after a section ([buildSeparator])
/// and whether that forces a page break ([breakAfterUse]). The available
/// strategies are:
///
/// * [PageBreakSeparatorStrategy] — breaks the page so the next content starts
///   on a fresh page.
/// * [SingleReturnSeparatorStrategy] — writes nothing, so the next document
///   continues right after the previous content.
/// * [CustomSeparatorStrategy] — writes the content supplied by the user.
/// * EmptyLineSeparatorStrategy — writes a `\n` to separate old and new
///   content.
///
/// Every strategy has a stable, unique [id]; serialization writes that id plus
/// any extra fields (see [toJson] and [fromJson]).
@immutable
abstract class LayoutSeparator {
  const LayoutSeparator();

  /// Whether using this separator must start a new page.
  @mustBeOverridden
  bool get breakAfterUse;

  /// Returns the literal content the separator writes.
  String buildSeparator();

  /// Stable identifier of this separator; every id must be unique so
  /// [fromJson] can resolve the strategy.
  @mustBeOverridden
  String get id;

  @override
  @mustBeOverridden
  bool operator ==(covariant LayoutSeparator other);

  @override
  @mustBeOverridden
  int get hashCode;

  /// Serializes the separator to its JSON object (the id plus strategy-specific
  /// fields added by subclasses).
  @mustCallSuper
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      LayoutSeparator.separatorIdKey: id,
    };
  }

  /// Resolves a separator from its JSON object.
  ///
  /// Returns the matching strategy for a known [separatorIdKey] value, or
  /// throws [UnknownLayoutSeparatorException] for an unknown/empty id.
  static LayoutSeparator? fromJson(Map<String, dynamic> json) {
    final String id = json[LayoutSeparator.separatorIdKey] as String? ?? '';
    final String customSeparatorStrategyId =
        CustomSeparatorStrategy.internal().id;
    final String pageBreakId = PageBreakSeparatorStrategy.instance.id;
    final String emptyLineId = EmptyLineSeparatorStrategy.instance.id;
    final String singleReturnId = SingleReturnSeparatorStrategy.instance.id;
    if (id == customSeparatorStrategyId) {
      return CustomSeparatorStrategy.fromJson(json);
    } else if (id == pageBreakId) {
      return PageBreakSeparatorStrategy.instance;
    } else if (id == emptyLineId) {
      return EmptyLineSeparatorStrategy.instance;
    } else if (id == singleReturnId) {
      return SingleReturnSeparatorStrategy.instance;
    }
    throw UnknownLayoutSeparatorException(id: id);
  }

  /// JSON key that carries the strategy id.
  @protected
  @visibleForTesting
  static const String separatorIdKey = 'separator_id';
}
