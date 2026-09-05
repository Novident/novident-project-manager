import 'package:meta/meta.dart';
import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:numerus/numerus.dart';

import '../../../../constants/constants.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';

final class ReplaceRomanNumberPlaceholderRule with PlaceholderRule {
  const ReplaceRomanNumberPlaceholderRule();

  @protected
  static const String romanNumLowercase = 'r';

  @protected
  static const String romanNumUppercase = 'R';

  @override
  RegExp get pattern => NovidentProjectDefaults.kRomanWordNumIndexPattern;

  @override
  bool checkIfNeedApply(Delta delta) => delta.toQuery.contains(
        target: pattern,
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
            final String indexType = match.group(2)!;
            final bool isUppercase = indexType == romanNumUppercase;
            final bool isLowercase = indexType == romanNumLowercase;
            int digitIndex = context.documentVariables[placeholderMatch] ?? 0;
            digitIndex++;
            context.documentVariables[placeholderMatch] = digitIndex;
            String str = digitIndex.toRomanNumeralString()!;
            if (isUppercase) {
              str = str.toUpperCase();
            } else if (isLowercase) {
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
        final String indexType = match.group(2)!;
        final bool isUppercase = indexType == romanNumUppercase;
        final bool isLowercase = indexType == romanNumLowercase;
        int digitIndex = context.documentVariables[placeholderMatch] ?? 0;
        digitIndex++;
        context.documentVariables[placeholderMatch] = digitIndex;
        String str = digitIndex.toRomanNumeralString()!;
        if (isUppercase) {
          str = str.toUpperCase();
        } else if (isLowercase) {
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
