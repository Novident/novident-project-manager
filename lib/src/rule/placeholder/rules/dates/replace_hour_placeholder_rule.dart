import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';

final class ReplaceHourPlaceholderRule with PlaceholderRule {
  const ReplaceHourPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kHourPattern;

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
          replace: '${context.time?.hour}',
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
      replace: '${context.time?.hour}',
      range: null,
      onlyOnce: false,
    );
  }
}
