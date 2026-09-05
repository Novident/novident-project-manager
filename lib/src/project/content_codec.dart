import 'dart:convert';

import 'package:novident_editor_document/novident_editor_document.dart';

/// Thin typed wrapper around `novident_editor_document`'s `Document`.
///
/// `content.json` (and the `content` field of `synopsis.json`) stores the
/// document in the editor's own format — `{ "document": … }` — so content is
/// read and written directly with `Document.fromJson` / `Document.toJson`,
/// without any intermediate parsing or transformation.
class ContentCodec {
  ContentCodec._();

  /// Decodes `content.json` into a `Document`.
  static Document decode(String contentJson) {
    return Document.fromJson(jsonDecode(contentJson) as Map<String, dynamic>);
  }

  /// Encodes a `Document` into `content.json` (JSON string).
  static String encode(Document document) {
    return jsonEncode(document.toJson());
  }
}

/// Codec for `synopsis.json`, which wraps the same editor `Document` in an
/// outer envelope:
/// ```json
/// { "type": "document", "metadata": {}, "content": { "document": … } }
/// ```
class SynopsisCodec {
  SynopsisCodec._();

  /// Extracts the inner editor `Document` from a `synopsis.json` string.
  static Document decode(String synopsisJson) {
    final Map<String, dynamic> outer =
        jsonDecode(synopsisJson) as Map<String, dynamic>;
    final Object? content = outer['content'];
    if (content is! Map<String, dynamic>) {
      throw const FormatException('synopsis.json has no content block');
    }
    return Document.fromJson(content);
  }

  /// Wraps an editor `Document` into the `synopsis.json` envelope.
  static String encode(Document document) {
    return jsonEncode(<String, dynamic>{
      'type': 'document',
      'metadata': <String, dynamic>{},
      'content': document.toJson(),
    });
  }
}
