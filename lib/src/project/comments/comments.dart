// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

/// Inline comments of a node (`files/<id>/comments.json`).
///
/// The file is an object whose keys are `<comment-id>[-<username>]` (see the
/// format spec §7) mapping to a [Comment].
class Comments {
  /// Comments keyed by their `<id>[-<username>]` anchor.
  final Map<String, Comment> comments;

  /// Builds the collection; defaults to empty.
  const Comments({this.comments = const <String, Comment>{}});

  /// Parses the collection from its on-disk JSON object, skipping non-object
  /// entries.
  factory Comments.fromJson(Map<String, dynamic> json) {
    final comments = <String, Comment>{};
    json.forEach((String key, dynamic value) {
      if (value is Map<String, dynamic>) {
        comments[key] = Comment.fromJson(value);
      }
    });
    return Comments(comments: comments);
  }

  /// Serializes the collection to its on-disk JSON object.
  Map<String, dynamic> toJson() => comments.map(
      (String key, Comment comment) => MapEntry(key, comment.toJson()));

  /// Serializes the collection to a JSON string.
  String toJsonString() => json.encode(toJson());

  /// Parses the collection from its JSON string.
  factory Comments.fromJsonString(String source) =>
      Comments.fromJson(json.decode(source) as Map<String, dynamic>);
}

/// A single anchored comment.
///
/// [path] is the position of the commented node in the content tree (indexes
/// into `children`), kept up to date automatically; [date] follows the
/// `MM/DD/YYYY` format and [content] is plain text.
class Comment {
  /// Structural position of the commented node inside the content tree.
  final List<int> path;

  /// Comment date (`MM/DD/YYYY`).
  final String date;

  /// Comment text (a plain string).
  final String content;

  /// Builds a comment; defaults are empty.
  const Comment({
    this.path = const <int>[],
    this.date = '',
    this.content = '',
  });

  /// Parses a comment from its on-disk JSON object (tolerant of missing
  /// fields).
  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        path: (json['path'] as List?)?.cast<int>() ?? const <int>[],
        date: json['date'] as String? ?? '',
        content: json['content'] as String? ?? '',
      );

  /// Serializes the comment to its on-disk JSON object.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'date': date,
        'content': content,
      };
}
