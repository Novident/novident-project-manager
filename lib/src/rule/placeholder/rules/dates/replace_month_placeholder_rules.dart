import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../extensions/string_extension.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';

final class ReplaceMonthPlaceholderRule with PlaceholderRule {
  const ReplaceMonthPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kMonthsPattern;

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
            if (match.group(1) == null) return <TextOperation>[];
            final bool isWordMonth = match.group(2) == ':n';
            if (isWordMonth) {
              return <TextInsert>[
                TextInsert(
                  NovidentConstants.kMonths[context.time?.month]!.capitalize(),
                  attributes: attributes,
                ),
              ];
            }
            return <TextInsert>[
              TextInsert(
                context.time!.month.toString(),
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
        if (match.group(1) == null) return <TextInsert>[];
        final bool isWordMonth = match.group(2) == ':n';
        if (isWordMonth) {
          return <TextInsert>[
            TextInsert(
              NovidentConstants.kMonths[context.time?.month]!.capitalize(),
              attributes: attributes,
            ),
          ];
        }
        return <TextInsert>[
          TextInsert(
            context.time!.month.toString(),
            attributes: attributes,
          ),
        ];
      },
    );
  }
}
