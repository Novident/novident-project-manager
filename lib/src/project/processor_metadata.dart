import 'dart:convert';

/// Legacy publication metadata model.
///
/// **Superseded by the `book` block of `Metadata`** (`Book`); kept for the
/// placeholder rules that read the project title/abbreviation (`<$projecttitle>`,
/// `<$abbr_title>`, `<$iscode>`).
class ProjectMetadata {
  /// Full project title (`<$projecttitle>`).
  final String projectTitle;

  /// Abbreviated title (`<$abbr_title>`).
  final String abbreviateTitle;

  /// ISBN code (`<$iscode>`).
  final String isbncode;

  /// Subject/theme description.
  final String subject;

  /// Publishing company.
  final String company;

  /// Copyright line.
  final String copyright;

  /// Keywords (usually comma separated).
  final String keywords;

  /// Free comments about the publication.
  final String comments;

  /// Builds the legacy metadata; every field is required.
  ProjectMetadata({
    required this.projectTitle,
    required this.abbreviateTitle,
    required this.isbncode,
    required this.subject,
    required this.company,
    required this.copyright,
    required this.keywords,
    required this.comments,
  });

  /// Builds empty metadata (defaults for PDF, LaTeX and Epub books).
  factory ProjectMetadata.basic() {
    return ProjectMetadata(
      projectTitle: '',
      abbreviateTitle: '',
      isbncode: '',
      subject: '',
      company: '',
      copyright: '',
      keywords: '',
      comments: '',
    );
  }

  /// Returns a copy with the given fields replaced.
  ProjectMetadata copyWith({
    String? projectTitle,
    String? abbreviateTitle,
    String? isbncode,
    String? surname,
    String? forename,
    String? subject,
    String? company,
    String? copyright,
    String? keywords,
    String? comments,
  }) {
    return ProjectMetadata(
      projectTitle: projectTitle ?? this.projectTitle,
      abbreviateTitle: abbreviateTitle ?? this.abbreviateTitle,
      isbncode: isbncode ?? this.isbncode,
      subject: subject ?? this.subject,
      company: company ?? this.company,
      copyright: copyright ?? this.copyright,
      keywords: keywords ?? this.keywords,
      comments: comments ?? this.comments,
    );
  }

  /// Serializes the metadata to its on-disk JSON map (snake_case keys).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'project_title': projectTitle,
      'abbreviate_title': abbreviateTitle,
      'isbncode': isbncode,
      'subject': subject,
      'company': company,
      'copyright': copyright,
      'keywords': keywords,
      'comments': comments,
    };
  }

  /// Parses the metadata from its on-disk JSON map (tolerant of missing
  /// fields).
  factory ProjectMetadata.fromMap(Map<String, dynamic> map) {
    return ProjectMetadata(
      projectTitle: map['project_title'] as String? ?? '',
      abbreviateTitle: map['abbreviate_title'] as String? ?? '',
      isbncode: map['isbncode'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      company: map['company'] as String? ?? '',
      copyright: map['copyright'] as String? ?? '',
      keywords: map['keywords'] as String? ?? '',
      comments: map['comments'] as String? ?? '',
    );
  }

  /// Serializes the metadata to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses the metadata from its JSON string.
  factory ProjectMetadata.fromJson(String source) =>
      ProjectMetadata.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ProjectMetadata('
        'projectTitle: $projectTitle, '
        'abbreviateTitle: $abbreviateTitle, '
        'isbncode: $isbncode, '
        'subject: $subject, '
        'company: $company, '
        'copyright: $copyright, '
        'keywords: $keywords, '
        'comments: $comments'
        ')';
  }

  @override
  bool operator ==(covariant ProjectMetadata other) {
    if (identical(this, other)) return true;

    return other.projectTitle == projectTitle &&
        other.abbreviateTitle == abbreviateTitle &&
        other.isbncode == isbncode &&
        other.subject == subject &&
        other.company == company &&
        other.copyright == copyright &&
        other.keywords == keywords &&
        other.comments == comments;
  }

  @override
  int get hashCode {
    return projectTitle.hashCode ^
        abbreviateTitle.hashCode ^
        subject.hashCode ^
        isbncode.hashCode ^
        company.hashCode ^
        copyright.hashCode ^
        keywords.hashCode ^
        comments.hashCode;
  }
}
