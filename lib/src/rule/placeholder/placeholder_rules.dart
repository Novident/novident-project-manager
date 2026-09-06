import 'package:meta/meta.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_project_manager/src/format/format.dart';
import 'package:novident_project_manager/src/rule/placeholder/placeholder_rule_mixin.dart';
import 'package:novident_project_manager/src/rule/placeholder/rules/replacement_value_rule.dart';
import 'package:novident_project_manager/src/rule/placeholder/type_placeholder_enum.dart';
import '../../layout/processor_context.dart';
import 'rules/rules.dart';

/// Immutable set of placeholder replacement rules, grouped by family.
///
/// A placeholder is a token of the form `<$…>` (for example `<$projecttitle>`,
/// `<$n>`, `<$page>` or a date token). The rules know how to detect a token of
/// their family inside a block [Delta] and how to rewrite it from the values of
/// a compilation [Context].
@immutable
final class PlaceholderRules {
  /// Builds the rules; every family defaults to the project's built-in rules.
  const PlaceholderRules({
    this.indexRules = _indexRules,
    this.dateRules = _dateRules,
    this.projectInfoRules = _projectInfoRules,
    this.customReplacements,
  });

  /// Rules that resolve counters and numbering tokens (`<$n>`, …).
  final List<PlaceholderRule> indexRules;

  /// Rules that resolve date/time tokens (today, year, month, time formats…).
  final List<PlaceholderRule> dateRules;

  /// Rules that resolve project metadata and count tokens (`<$projecttitle>`,
  /// author, word/character counts, image, ISBN…).
  final List<PlaceholderRule> projectInfoRules;

  final ReplacementsValues? customReplacements;

  /// Matches any `<$…>` token inside a delta.
  static final RegExp _commonPlaceholderDetector = RegExp(r'<\$[^>]+>');

  /// Default index rules: reset counters and replace numbering tokens.
  static const List<PlaceholderRule> _indexRules = <PlaceholderRule>[
    ResetPlaceholderInvokation(),
    ReplaceNumCountPlaceholderRule(),
    ReplaceSubNumCountPlaceholderRule(),
    ReplaceRomanNumberPlaceholderRule(),
    ReplaceDoubleNumberingPlaceholderRule(),
    ReplaceWordNumberPlaceholderRule(),
  ];

  /// Default date rules: replace each supported date/time token.
  static const List<PlaceholderRule> _dateRules = <PlaceholderRule>[
    ReplaceMinutePlaceholderRule(),
    ReplaceMillisecondsPlaceholderRule(),
    ReplaceMicrosecondsPlaceholderRule(),
    ReplaceSecondsPlaceholderRule(),
    ReplaceHourFormatPlaceholderRule(),
    ReplaceDayPlaceholderRule(),
    ReplaceTodayPlaceholderRule(),
    ReplaceYearPlaceholderRule(),
    ReplaceWeekdayPlaceholderRule(),
    ReplaceMonthPlaceholderRule(),
  ];

  /// Default project rules: counts first, then metadata placeholders.
  static const List<PlaceholderRule> _projectInfoRules = <PlaceholderRule>[
    // Counts
    ReplaceWordCountPlaceholderRule(),
    ReplaceCharacterCountPlaceholderRule(),
    ReplaceLineCountPlaceholderRule(),
    // Metadata
    ReplaceImagePlaceholderRule(),
    ReplaceDocumentTitlePlaceholderRule(),
    ReplaceProjectTitlePlaceholderRule(),
    ReplaceAbbreviateTitlePlaceholderRule(),
    ReplaceAuthorInfoPlaceholderRule(),
    ReplaceISBNPlaceholderRule(),
  ];

  /// Applies the rules of [type] to every block of [document] that contains a
  /// placeholder token, using the project data from [context].
  ///
  /// The document is deep-copied first and the result is returned as a new
  /// [Document]; the receiver is never mutated. When [Context.placeholderDisabled]
  /// is true (or the document has no content) the original [document] is
  /// returned unchanged.
  ///
  /// Blocks whose delta is empty or has no `<$…>` token are skipped. Blocks
  /// that resolve to a single image placeholder are rewritten as an image node
  /// (see `ImageBlockKeys`); the remaining families are applied by detecting
  /// each matching rule and aggregating the resulting conditions into a
  /// `QueryDelta` before writing the new delta back.
  ///
  /// The `dates` family sets `context.time` to the current time before
  /// applying its rules.
  ///
  /// The returned document is ready to be used for compilations.
  Document applyRules(
    Document document,
    TypePlaceholder type,
    Context context,
  ) {
    final clone = Document(root: document.root.deepCopy());
    if (context.placeholderDisabled || clone.isEmpty) return document;
    final replacements = compileReplacementValues(customReplacements!);
    if (indexRules.isEmpty &&
        projectInfoRules.isEmpty &&
        dateRules.isEmpty &&
        replacements.isEmpty) {
      return document;
    }
    // to avoid recomputing every time this list, we can just catch it before the loop
    final all = type == TypePlaceholder.all
        ? <PlaceholderRule>[
            ...indexRules,
            ...dateRules,
            ...projectInfoRules,
          ]
        : null;
    for (int index = 0; index < clone.root.length; index++) {
      if (document.root.children[index].delta == null) {
        continue;
      }
      final delta = document.root.children[index].delta!;
      if (delta.isEmpty ||
          delta.firstMatch(
                _commonPlaceholderDetector,
                null,
              ) ==
              null) {
        continue;
      }

      // Replacing a full node content requires a full rewrite of the node:
      // a block whose only content is an image placeholder is converted into
      // an image block instead of leaving a text delta behind.
      if (delta.operations.length == 1 &&
          _projectInfoRules[3].checkIfNeedApply(delta)) {
        final newDelta = _projectInfoRules[3].apply(
          delta,
          context,
        );

        final image = newDelta.operations[0];
        final hasAttributes = image.attributes != null;
        clone.root.children[index] = clone.root.children[index].copyWith(
          type: ImageBlockKeys.type,
          attributes: {
            ImageBlockKeys.url: image.attributes![ImageBlockKeys.url],
            if (hasAttributes &&
                image.attributes?[ImageBlockKeys.width] != null)
              ImageBlockKeys.width: image.attributes?[ImageBlockKeys.width],
            if (hasAttributes &&
                image.attributes?[ImageBlockKeys.height] != null)
              ImageBlockKeys.height: image.attributes?[ImageBlockKeys.height],
            if (hasAttributes &&
                image.attributes?[ImageBlockKeys.align] != null)
              ImageBlockKeys.align: image.attributes?[ImageBlockKeys.align],
          },
        );
        continue;
      }

      QueryDelta query = QueryDelta(delta: delta);

      if (customReplacements != null) {
        for (final PlaceholderRule rule in replacements) {
          if (rule.checkIfNeedApply(delta)) {
            query = rule.setConditionRule(query, context);
          }
        }
      }

      if (type == TypePlaceholder.all) {
        for (final PlaceholderRule rule in all!) {
          if (rule.checkIfNeedApply(delta)) {
            query = rule.setConditionRule(query, context);
          }
        }
      }

      if (type == TypePlaceholder.indexes && indexRules.isNotEmpty) {
        for (final PlaceholderRule rule in indexRules) {
          if (rule.checkIfNeedApply(delta)) {
            query = rule.setConditionRule(query, context);
          }
        }
      }
      if (type == TypePlaceholder.dates && dateRules.isNotEmpty) {
        context.time = DateTime.now();
        for (final PlaceholderRule rule in dateRules) {
          if (rule.checkIfNeedApply(delta)) {
            query = rule.setConditionRule(query, context);
          }
        }
      }
      if (type == TypePlaceholder.projectInfo && projectInfoRules.isNotEmpty) {
        for (final PlaceholderRule rule in projectInfoRules) {
          if (rule.checkIfNeedApply(delta)) {
            query = rule.setConditionRule(query, context);
          }
        }
      }

      clone.root.children[index].attributes['delta'] = query.build().delta;
    }
    return clone;
  }

  List<PlaceholderRule> compileReplacementValues(ReplacementsValues values) {
    final replacements = values.replacements;
    final rules = <PlaceholderRule>[];
    for (int index = 0; index < replacements.length; index++) {
      final replacement = replacements.elementAt(index);
      if (!replacement.enabled) continue;
      rules.add(
        ReplacementValueRule(
          regexp: replacement.isRegexp
              ? replacement.regexp!
              : RegExp(
                  replacement.find,
                  caseSensitive: replacement.caseSensitive,
                ),
          replacement: replacement.replace,
        ),
      );
    }
    return rules;
  }
}
