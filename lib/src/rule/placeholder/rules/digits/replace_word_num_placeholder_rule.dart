import 'package:humanize_numbers/humanize_numbers.dart';
import 'package:meta/meta.dart';
import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../extensions/string_extension.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';

final class ReplaceWordNumberPlaceholderRule with PlaceholderRule {
  const ReplaceWordNumberPlaceholderRule();

  @protected
  static final HumanizeNumber parser = HumanizeNumber();

  @protected
  static const String wordNumLowercase = 'w';

  @protected
  static const String wordNumUppercase = 'W';

  @protected
  static const String wordNumTitlecase = 't';

  @override
  RegExp get pattern => NovidentProjectDefaults.kWordNumCountPattern;

  @override
  bool checkIfNeedApply(Delta delta) => delta.toQuery.contains(
        target: pattern.pattern,
        usePlainText: true,
      );

  @override
  Delta apply(Delta delta, Context context) {
    return delta.toQuery
        .replaceAllMapped(
          target: pattern.pattern,
          replaceBuilder: (
            String data,
            Map<String, dynamic>? attributes,
            DeltaRange curRange,
            DeltaRange matchRange,
          ) {
            final RegExpMatch match = pattern.firstMatch(data)!;
            final String? placeholderMatch = match.group(1);
            if (placeholderMatch == null) return <TextInsert>[];
            final String? indexType = match.group(2);
            final bool isTitlecase = indexType == wordNumTitlecase;
            final bool isWordNumUppercase = indexType == wordNumUppercase;
            final bool isWordNumLowercase = indexType == wordNumLowercase;
            int digitIndex = context.documentVariables[placeholderMatch] ?? 0;
            digitIndex++;
            context.documentVariables[placeholderMatch] = digitIndex;
            String str = parser.parse(digitIndex, context.language);
            if (isTitlecase) {
              str = str.capitalize();
            } else if (isWordNumUppercase) {
              str = str.toUpperCase();
            } else if (isWordNumLowercase) {
              str = str.toLowerCase();
            }
            return <TextInsert>[
              TextInsert(
                str,
                attributes: attributes,
              ),
            ];
          },
        )
        .build()
        .delta;
  }

  @override
  QueryDelta setConditionRule(QueryDelta query, Context context) {
    return query.replaceAllMapped(
      target: pattern.pattern,
      replaceBuilder: (
        String data,
        Map<String, dynamic>? attributes,
        DeltaRange curRange,
        DeltaRange matchRange,
      ) {
        final RegExpMatch match = pattern.firstMatch(data)!;
        final String? placeholderMatch = match.group(1);
        if (placeholderMatch == null) return <TextInsert>[];
        final String? indexType = match.group(2);
        final bool isTitlecase = indexType == wordNumTitlecase;
        final bool isWordNumUppercase = indexType == wordNumUppercase;
        final bool isWordNumLowercase = indexType == wordNumLowercase;
        int digitIndex = context.documentVariables[placeholderMatch] ?? 0;
        digitIndex++;
        context.documentVariables[placeholderMatch] = digitIndex;
        String str = parser.parse(digitIndex, context.language);
        if (isTitlecase) {
          str = str.capitalize();
        } else if (isWordNumUppercase) {
          str = str.toUpperCase();
        } else if (isWordNumLowercase) {
          str = str.toLowerCase();
        }
        return <TextInsert>[
          TextInsert(
            str,
            attributes: attributes,
          ),
        ];
      },
    );
  }
}
