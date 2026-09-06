import 'dart:convert';

import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_project_manager/src/project/synopsis/synopsis.dart';

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

class SynopsisCodec {
  SynopsisCodec._();

  static Synopsis decode(String synopsisJson) {
    return Synopsis.fromJson(jsonDecode(synopsisJson));
  }

  static String encode(Synopsis synopsis) {
    return jsonEncode(synopsis.toJson());
  }
}
