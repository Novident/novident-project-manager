import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';

/// Gets replaced during the Compile process with the total word count of the text
/// currently being compiled.
//TODO:  We need to add support for rounding to the limit specified by the pattern: [50, 100, 500, 1000, 10000] limits
final class ReplaceWordCountPlaceholderRule with PlaceholderRule {
  const ReplaceWordCountPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kWordCountPattern;

  @override
  bool checkIfNeedApply(Delta delta) => delta.toQuery.contains(
        target: pattern,
        usePlainText: true,
      );

  @override
  Delta apply(Delta delta, Context context) {
    return delta.toQuery
        .replace(
          target: pattern.pattern,
          replace: context.wordsCount.toString(),
          range: null,
          onlyOnce: false,
        )
        .build()
        .delta;
  }

  @override
  QueryDelta setConditionRule(QueryDelta query, Context context) {
    return query.replace(
      target: pattern.pattern,
      replace: context.wordsCount.toString(),
      range: null,
      onlyOnce: false,
    );
  }
}

/// Gets replaced during the Compile process with the total character count of the
/// text currently being compiled.
final class ReplaceCharacterCountPlaceholderRule with PlaceholderRule {
  const ReplaceCharacterCountPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kCharacterCountPattern;

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
            // the first group should prepare the count to end
            // when the max amount of chars ends
            // with (d+) (can be 1.100 or 2.100)
            replaceBuilder: (
              String data,
              Map<String, dynamic>? attributes,
              DeltaRange curRange,
              DeltaRange matchRange,
            ) {
              return <TextInsert>[
                TextInsert(
                  context.charsCount.toString(),
                  attributes: attributes,
                ),
              ];
            })
        .build()
        .delta;
  }

  @override
  QueryDelta setConditionRule(QueryDelta query, Context context) {
    return query.replaceAllMapped(
        target: pattern.pattern,
        // the first group should prepare the count to end
        // when the max amount of chars ends
        // with (d+) (can be 1.100 or 2.100)
        replaceBuilder: (
          String data,
          Map<String, dynamic>? attributes,
          DeltaRange curRange,
          DeltaRange matchRange,
        ) {
          return <TextInsert>[
            TextInsert(
              context.charsCount.toString(),
              attributes: attributes,
            ),
          ];
        });
  }
}
