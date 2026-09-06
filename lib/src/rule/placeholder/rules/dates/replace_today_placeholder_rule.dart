import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../extensions/string_extension.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';

final class ReplaceTodayPlaceholderRule with PlaceholderRule {
  const ReplaceTodayPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kTodayPattern;

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
          replace:
              '${NovidentConstants.kMonths[context.time?.month]!.capitalize()} '
              '${context.time?.day}, '
              '${context.time?.year}',
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
      replace:
          '${NovidentConstants.kMonths[context.time?.month]!.capitalize()} '
          '${context.time?.day}, '
          '${context.time?.year}',
      range: null,
      onlyOnce: false,
    );
  }
}

final class ReplaceWeekdayPlaceholderRule with PlaceholderRule {
  const ReplaceWeekdayPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kWeekdayPattern;

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
          replace: '${context.time?.weekday}'.capitalize(),
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
      replace: '${context.time?.weekday}',
      range: null,
      onlyOnce: false,
    );
  }
}
