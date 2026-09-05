import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';
import '../../utils/string_utils.dart';

/// Gets replaced with the abbreviated project name during the Compile process.
/// The abbreviated project name is taken from metadata pane of the Compile panel.
///
/// If the placeholder appears in uppercase, the abbreviated project name will be
/// uppercased too.
final class ReplaceAbbreviateTitlePlaceholderRule with PlaceholderRule {
  const ReplaceAbbreviateTitlePlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kAbbreviateTitlePattern;

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
            final RegExpMatch? match = pattern.firstMatch(data);
            if (match == null || match.group(1) == null) return <TextInsert>[];
            final String type = match.group(1)!;
            return <TextInsert>[
              TextInsert(
                isUppercase(type)
                    ? context.metadata.abbreviateTitle.toUpperCase()
                    : context.metadata.abbreviateTitle,
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
        final RegExpMatch? match = pattern.firstMatch(data);
        if (match == null || match.group(1) == null) return <TextInsert>[];
        final String type = match.group(1)!;
        return <TextInsert>[
          TextInsert(
            isUppercase(type)
                ? context.metadata.abbreviateTitle.toUpperCase()
                : context.metadata.abbreviateTitle,
            attributes: attributes,
          ),
        ];
      },
    );
  }
}
