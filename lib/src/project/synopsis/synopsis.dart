import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_project_manager/src/extensions/cast_extension.dart';

class Synopsis {
  /// Structural position of the commented node inside the content tree.
  final String type;

  /// Metadata assigned to this synopsis.
  final Map<String, dynamic>? metadata;

  /// Comment text (a plain string).
  final Object content;

  const Synopsis({
    required this.type,
    required this.metadata,
    required this.content,
  });

  Synopsis.document({
    required this.content,
  })  : type = _documentKey,
        metadata = {};

  Synopsis.image({
    required this.content,
  })  : type = _imageKey,
        metadata = {};

  static const String _documentKey = 'document';
  static const String _imageKey = 'image';

  /// Whether this synopsis contains a document content
  bool get isDocument => type == _documentKey;

  /// Whether this synopsis contains a image content
  bool get isImage => type == _imageKey;

  /// Parses a comment from its on-disk JSON object (tolerant of missing
  /// fields).
  factory Synopsis.fromJson(Map<String, dynamic> json) {
    assert(json['content'] != null, 'content must not be null');
    return Synopsis(
      type: json['type'] as String,
      metadata: Map.from(json['metadata'] as Map),
      content: json['type'] == _documentKey
          ? Document.fromJson(json['content'])
          : json['content'] as Object,
    );
  }

  /// Serializes the comment to its on-disk JSON object.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'metadata': metadata,
        'content': isDocument ? content.cast<Document>().toJson() : content,
      };
}
