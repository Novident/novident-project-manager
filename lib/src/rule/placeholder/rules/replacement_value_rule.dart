import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../layout/processor_context.dart';
import '../placeholder_rule_mixin.dart';

final class ReplacementValueRule with PlaceholderRule {
  final RegExp regexp;
  final String replacement;
  const ReplacementValueRule({
    required this.regexp,
    required this.replacement,
  });

  @override
  RegExp get pattern => regexp;

  @override
  bool checkIfNeedApply(Delta delta) => delta.toPlainText().contains(pattern);

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
            return <TextOperation>[
              TextInsert(
                replacement,
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
        return <TextOperation>[
          TextInsert(
            replacement,
            attributes: attributes,
          ),
        ];
      },
    );
  }
}
