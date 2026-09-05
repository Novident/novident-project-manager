import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';

/// Gets replaced with the line count of the document during the Compile process. If
/// associated with an internal document link, the line count will show the number of
/// lines in the linked document.
final class ReplaceLineCountPlaceholderRule with PlaceholderRule {
  const ReplaceLineCountPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kLineCountPattern;

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
          replace: context.linecount.toString(),
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
      replace: context.linecount.toString(),
      range: null,
      onlyOnce: false,
    );
  }
}
