import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_document_format/novident_document_format.dart';

import '../../../constants/constants.dart';
import '../../../layout/processor_context.dart';
import '../placeholder_rule_mixin.dart';

final class ReplaceImagePlaceholderRule with PlaceholderRule {
  const ReplaceImagePlaceholderRule();

  @override
  RegExp get pattern => NovidentProjectDefaults.kImagePattern;

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
            // old implementation
            // ```
            // final RegExpMatch match = _imagePattern.firstMatch(data)!;
            // final String src = match.group(1)!;
            // ```
            //
            // Context:
            //
            // We split these values since those could be like:
            //
            // ```
            //  <$img:BookImageRefName;w=20;h=300:cover>
            //  <$img:BookImageRefName>
            // ```
            //
            // So, we need to get all properties to apply these ones to the image
            // Note: if empty means the tag has just the name reference like: <$img:BookImage>
            final List<String> properties = data.split(';');
            if (properties.isEmpty) {
              final DocumentResource? file =
                  context.queryResource(data.split(':').last);
              if (file == null) {
                return <TextOperation>[];
              }
              final String effectiveImageData =
                  file.resource(ResourceType.image) as String;
              if (effectiveImageData.isEmpty) return [];
              return <TextOperation>[
                TextInsert('', attributes: <String, String>{
                  'url': effectiveImageData,
                })
              ];
            }
            final String fileName = properties.first;
            final DocumentResource? file = context.queryResource(fileName);
            if (file == null) {
              return <TextOperation>[];
            }
            final String imagePath =
                file.resource(ResourceType.image) as String;
            if (imagePath.isEmpty) return [];
            final num? width = num.tryParse(
              properties
                      .where((String element) => element.startsWith('w='))
                      .firstOrNull ??
                  '',
            );
            final num? height = num.tryParse(
              properties
                      .where((String element) => element.startsWith('h='))
                      .firstOrNull ??
                  '',
            );
            return <TextOperation>[
              TextInsert('', attributes: <String, dynamic>{
                'url': imagePath,
                if (width != null) 'width': width,
                if (height != null && width == null) 'width': height / 2,
                if (height != null) 'height': height,
              })
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
        // old implementation
        // ```
        // final RegExpMatch match = _imagePattern.firstMatch(data)!;
        // final String src = match.group(1)!;
        // ```
        //
        // Context:
        //
        // We split these values since those could be like:
        //
        // ```
        //  <$img:BookImageRefName;w=20;h=300:cover>
        //  <$img:BookImageRefName>
        // ```
        //
        // So, we need to get all properties to apply these ones to the image
        // Note: if empty means the tag has just the name reference like: <$img:BookImage>
        final List<String> properties = data.split(';');
        if (properties.isEmpty) {
          final DocumentResource? file =
              context.queryResource(data.split(':').last);
          if (file == null) {
            return <TextOperation>[];
          }
          final String effectiveImageData =
              file.resource(ResourceType.image) as String;
          if (effectiveImageData.isEmpty) return [];
          return <TextOperation>[
            TextInsert('', attributes: <String, String>{
              'url': effectiveImageData,
            })
          ];
        }
        final String fileName = properties.first;
        final DocumentResource? file = context.queryResource(fileName);
        if (file == null) {
          return <TextOperation>[];
        }
        final String imagePath = file.resource(ResourceType.image) as String;
        if (imagePath.isEmpty) return [];
        final num? width = num.tryParse(
          properties
                  .where((String element) => element.startsWith('w='))
                  .firstOrNull ??
              '',
        );
        final num? height = num.tryParse(
          properties
                  .where((String element) => element.startsWith('h='))
                  .firstOrNull ??
              '',
        );
        return <TextOperation>[
          TextInsert('', attributes: <String, dynamic>{
            'url': imagePath,
            if (width != null) 'width': width,
            if (height != null && width == null) 'width': height / 2,
            if (height != null) 'height': height,
          })
        ];
      },
    );
  }
}
