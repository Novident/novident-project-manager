import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';

final class ReplaceDoubleNumberingPlaceholderRule with PlaceholderRule {
  const ReplaceDoubleNumberingPlaceholderRule();

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
            // its output should be like:
            // 1.0 -> 1.1 -> 2.5
            final String? placeholderMatch = match.group(1);
            if (placeholderMatch == null) return <TextInsert>[];
            double effectiveDoubleIndex = 1.0;
            const double increment = 0.1;
            final int count = context.documentVariables[placeholderMatch] ?? 0;
            for (int i = 0; i < count; i++) {
              effectiveDoubleIndex = double.parse(
                (effectiveDoubleIndex + increment).toStringAsFixed(1),
              );
            }
            context.documentVariables[placeholderMatch] = count + 1;
            // we need to format the strings, because
            // sometimes, the double value that we are creating
            // looks similar to:
            //
            // 1.2000000000002
            // 1.3000000000000003
            return <TextInsert>[
              TextInsert(
                effectiveDoubleIndex.toStringAsFixed(1),
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
        // its output should be like:
        // 1.0 -> 1.1 -> 2.5
        final String? placeholderMatch = match.group(1);
        if (placeholderMatch == null) return <TextInsert>[];
        const double increment = 0.1;
        double effectiveDoubleIndex = 1.0;
        final int count = context.documentVariables[placeholderMatch] ?? 0;
        for (int i = 0; i < count; i++) {
          effectiveDoubleIndex = double.parse(
            (effectiveDoubleIndex + increment).toStringAsFixed(1),
          );
        }
        context.documentVariables[placeholderMatch] = count + 1;

        // we need to format the strings, because
        // sometimes, the double value that we are creating
        // looks similar to:
        //
        // 1.2000000000002
        // 1.3000000000000003
        return <TextInsert>[
          TextInsert(
            effectiveDoubleIndex.toStringAsFixed(1),
            attributes: attributes,
          ),
        ];
      },
    );
  }
}
