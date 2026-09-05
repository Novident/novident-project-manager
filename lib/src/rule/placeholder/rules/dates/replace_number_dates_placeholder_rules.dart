import 'package:intl/intl.dart';
import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';

final class ReplaceMillisecondsPlaceholderRule with PlaceholderRule {
  const ReplaceMillisecondsPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kMillisecondPattern;

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
          replace: '${context.time?.millisecond}',
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
      replace: '${context.time?.millisecond}',
      range: null,
      onlyOnce: false,
    );
  }
}

final class ReplaceMicrosecondsPlaceholderRule with PlaceholderRule {
  const ReplaceMicrosecondsPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kMicrosecondPattern;

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
          replace: '${context.time?.microsecond}',
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
      replace: '${context.time?.microsecond}',
      range: null,
      onlyOnce: false,
    );
  }
}

final class ReplaceSecondsPlaceholderRule with PlaceholderRule {
  const ReplaceSecondsPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kSecondPattern;

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
          replace: '${context.time?.second}',
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
      replace: '${context.time?.second}',
      range: null,
      onlyOnce: false,
    );
  }
}

final class ReplaceMinutePlaceholderRule with PlaceholderRule {
  const ReplaceMinutePlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kMinutePattern;

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
          replace: '${context.time?.minute}',
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
      replace: '${context.time?.minute}',
      range: null,
      onlyOnce: false,
    );
  }
}

final class ReplaceHourFormatPlaceholderRule with PlaceholderRule {
  const ReplaceHourFormatPlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kHourFormatPattern;

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
          replace: DateFormat('HH:mm:ss').format(context.time!),
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
      replace: DateFormat('HH:mm:ss').format(context.time!),
      range: null,
      onlyOnce: false,
    );
  }
}
