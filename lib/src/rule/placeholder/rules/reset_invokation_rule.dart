
import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../constants/constants.dart';
import '../../../extensions/string_extension.dart';
import '../../../layout/processor_context.dart';
import '../placeholder_rule_mixin.dart';

final class ResetPlaceholderInvokation with PlaceholderRule {
  const ResetPlaceholderInvokation();

  @override
  RegExp get pattern => NovidentProjectDefaults.kResetCountsInvokation;

  @override
  bool checkIfNeedApply(Delta delta) => delta.toPlainText().contains(pattern);

  @override
  Delta apply(Delta delta, Context context) {
    return delta.toQuery
        .replaceAllMapped(
          replaceBuilder: (
            String data,
            Map<String, dynamic>? attributes,
            DeltaRange curRange,
            DeltaRange matchRange,
          ) {
            final RegExpMatch match = pattern.firstMatch(data)!;
            // matches with <$rs(type index)_(namedgroup)>
            // and removes then from document variables to reset count
            if (match.group(1) == null) return <TextOperation>[];
            final String indexType = match.group(2)!;
            final String? indexGroup = match.group(3);
            if (indexType.equals('all', caseSensitive: false)) {
              context.documentVariables.clear();
              return <TextOperation>[];
            }
            final String placeholder =
                '<\$$indexType${indexGroup != null ? ':$indexGroup' : ''}>';
            context.documentVariables.remove(placeholder);
            return <TextOperation>[];
          },
          target: pattern.pattern,
        )
        .build()
        .delta;
  }

  @override
  QueryDelta setConditionRule(QueryDelta query, Context context) {
    return query.replaceAllMapped(
      replaceBuilder: (
        String data,
        Map<String, dynamic>? attributes,
        DeltaRange curRange,
        DeltaRange matchRange,
      ) {
        final RegExpMatch match = pattern.firstMatch(data)!;
        // matches with <$rs(type index)_(namedgroup)>
        // and removes then from document variables to reset count
        if (match.group(1) == null) return <TextOperation>[];
        final String indexType = match.group(2)!;
        final String? indexGroup = match.group(3);
        if (indexType.equals('all', caseSensitive: false)) {
          context.documentVariables.clear();
          return <TextOperation>[];
        }
        final String placeholder =
            '<\$$indexType${indexGroup != null ? ':$indexGroup' : ''}>';
        context.documentVariables.remove(placeholder);
        return <TextOperation>[];
      },
      target: pattern.pattern,
    );
  }
}
