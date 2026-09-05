import 'package:meta/meta.dart';
import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../../../constants/constants.dart';
import '../../../../layout/processor_context.dart';
import '../../placeholder_rule_mixin.dart';
import '../../utils/string_utils.dart';

/// Gets replaced with the author info during the Compile process.
final class ReplaceAuthorInfoPlaceholderRule with PlaceholderRule {
  const ReplaceAuthorInfoPlaceholderRule();

  @protected
  static const String forenameKey = 'forename';

  @protected
  static const String authorKey = 'author';

  @protected
  static const String surnameKey = 'surname';

  @protected
  static const String lastnameKey = 'lastname';

  @protected
  static const String firstnameKey = 'firstname';

  @protected
  static const String fullnameKey = 'fullname';

  @override
  RegExp get pattern => NovidentProjectDefaults.kAuthorPattern;

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
            final String index = match.group(3) ?? 'all';
            String str = '';
            // firstname and forename are equivalent
            if ((type == firstnameKey || type == firstnameKey.toUpperCase()) ||
                (type == forenameKey || type == forenameKey.toUpperCase())) {
              str = context.author.getFirstname(index);
            }
            // lastname and surname are equivalent
            if ((type == lastnameKey || type == lastnameKey.toUpperCase()) ||
                (type == surnameKey || type == surnameKey.toUpperCase())) {
              str = context.author.getLastName(index);
            }
            if ((type == authorKey || type == authorKey.toUpperCase()) ||
                (type == fullnameKey || type == fullnameKey.toUpperCase())) {
              str = context.author.getAuthorName(index);
            }

            return <TextInsert>[
              TextInsert(
                isUppercase(type) ? str.toUpperCase() : str,
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
        final String index = match.group(3) ?? 'all';
        String str = '';
        // firstname and forename are equivalent
        if ((type == firstnameKey || type == firstnameKey.toUpperCase()) ||
            (type == forenameKey || type == forenameKey.toUpperCase())) {
          str = context.author.getFirstname(index);
        }
        // lastname and surname are equivalent
        if ((type == lastnameKey || type == lastnameKey.toUpperCase()) ||
            (type == surnameKey || type == surnameKey.toUpperCase())) {
          str = context.author.getLastName(index);
        }
        if ((type == authorKey || type == authorKey.toUpperCase()) ||
            (type == fullnameKey || type == fullnameKey.toUpperCase())) {
          str = context.author.getAuthorName(index);
        }

        return <TextInsert>[
          TextInsert(
            isUppercase(type) ? str.toUpperCase() : str,
            attributes: attributes,
          ),
        ];
      },
    );
  }
}
