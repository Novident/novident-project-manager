import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';
import '../../utils/string_utils.dart';

/// Gets replaced with the document title name during the Compile process.
///
/// If the placeholder appears in uppercase, the document title name will be
/// uppercased too.
final class ReplaceDocumentTitlePlaceholderRule with PlaceholderRule {
  const ReplaceDocumentTitlePlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kDocumentTitlePattern;

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
                    ? context.currentDocument!.objectName.toUpperCase()
                    : context.currentDocument!.objectName,
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
                ? context.currentDocument!.objectName.toUpperCase()
                : context.currentDocument!.objectName,
            attributes: attributes,
          ),
        ];
      },
    );
  }
}
