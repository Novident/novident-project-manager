import 'dart:convert';

/// A writing section type (a category of material with its own layout).
///
/// Section types typify components of a book: a way of categorizing elements
/// of the work. The differentiating features are set within the section
/// layouts, but you need a list of these categories before configuring a
/// format to suit your requirements. They give names to the different kinds of
/// material that require different formatting at compile time.
///
/// In the `.nov` file a section is simply a free string; this model mirrors the
/// list entries of `sections.index.json` with the id equal to the name.
class Section {
  /// Section id (equals the section string in the `.nov` list).
  final String id;

  /// Human-readable section name.
  final String name;

  /// Builds a section.
  Section({
    required this.id,
    required this.name,
  });

  /// Returns a copy with the given values replaced.
  Section copyWith({
    String? id,
    String? name,
  }) {
    return Section(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  /// Serializes the section to a JSON map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
    };
  }

  /// Parses a section from a JSON map.
  factory Section.fromMap(Map<String, dynamic> map) {
    return Section(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  /// Serializes the section to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses a section from its JSON string.
  factory Section.fromJson(String source) =>
      Section.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'Section(id: $id, name: $name)';

  @override
  bool operator ==(covariant Section other) {
    if (identical(this, other)) return true;

    return other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
