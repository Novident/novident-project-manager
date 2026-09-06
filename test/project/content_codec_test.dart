import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/content_codec.dart';

void main() {
  test('ContentCodec roundtrips the {"document":…} envelope', () {
    const String content =
        '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"Título"}]}}]}}';

    final document = ContentCodec.decode(content);
    final encoded = ContentCodec.encode(document);

    expect(json.decode(encoded), json.decode(content));
  });

  test('SynopsisCodec extracts the inner editor document', () {
    const String synopsis = '''
{
  "type": "document",
  "metadata": {},
  "content": {
    "document": {
      "type": "page",
      "children": [
        { "type": "paragraph", "data": { "delta": [ {"insert": "Sinopsis…"} ] } }
      ]
    }
  }
}
''';

    final document = SynopsisCodec.decode(synopsis);
    final encoded = SynopsisCodec.encode(document);
    final Map<String, dynamic> map =
        json.decode(encoded) as Map<String, dynamic>;

    // The envelope is rebuilt with type/metadata and the same inner content.
    expect(map['type'], 'document');
    expect(map['metadata'], isEmpty);
    expect(map['content'],
        (json.decode(synopsis) as Map<String, dynamic>)['content']);
  });
}
