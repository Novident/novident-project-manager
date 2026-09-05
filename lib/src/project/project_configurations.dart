// ignore_for_file: non_constant_identifier_names

import 'package:flutter/foundation.dart';
import '../schema/registry.dart';
import 'author/author.dart';

/// Compilation defaults: which format and output type are used by default.
class CompileDefaults {
  /// Points to `compiler/formats/<id>.json`.
  final String defaultFormatId;
  final String defaultOutput;
  final bool includeSynopsis;
  final bool includeNotes;
  final bool includeComments;

  const CompileDefaults({
    this.defaultFormatId = '',
    this.defaultOutput = '',
    this.includeSynopsis = false,
    this.includeNotes = false,
    this.includeComments = false,
  });

  factory CompileDefaults.fromJson(Map<String, dynamic> json) =>
      CompileDefaults(
        defaultFormatId: json['default_format_id'] as String? ?? '',
        defaultOutput: json['default_output'] as String? ?? '',
        includeSynopsis: json['include_synopsis'] as bool? ?? false,
        includeNotes: json['include_notes'] as bool? ?? false,
        includeComments: json['include_comments'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'default_format_id': defaultFormatId,
        'default_output': defaultOutput,
        'include_synopsis': includeSynopsis,
        'include_notes': includeNotes,
        'include_comments': includeComments,
      };

  @override
  int get hashCode => Object.hash(defaultFormatId, defaultOutput,
      includeSynopsis, includeNotes, includeComments);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompileDefaults &&
          runtimeType == other.runtimeType &&
          defaultFormatId == other.defaultFormatId &&
          defaultOutput == other.defaultOutput &&
          includeSynopsis == other.includeSynopsis &&
          includeNotes == other.includeNotes &&
          includeComments == other.includeComments;
}

/// Editor preferences (panels visibility, base style, page width, theme).
class EditorPreferences {
  final bool binder;
  final bool inspector;
  final String baseStyleRef;
  final int pageWidth;
  final String theme;

  /// When closing a writing session, recount every document to compute its
  /// counters. When `false` the app trusts the counts reported by an external
  /// counting service (see `ProjectManager.adjustOpenSession`) and skips the
  /// (expensive) recount — only structural statistics are still recomputed.
  final bool computeCountOnCloseSession;

  const EditorPreferences({
    this.binder = false,
    this.inspector = false,
    this.baseStyleRef = '',
    this.pageWidth = 0,
    this.theme = '',
    this.computeCountOnCloseSession = true,
  });

  factory EditorPreferences.fromJson(Map<String, dynamic> json) =>
      EditorPreferences(
        binder: json['binder'] as bool? ?? false,
        inspector: json['inspector'] as bool? ?? false,
        baseStyleRef: json['base_style_ref'] as String? ?? '',
        pageWidth: json['page_width'] as int? ?? 0,
        theme: json['theme'] as String? ?? '',
        computeCountOnCloseSession:
            json['compute_count_on_close_session'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'binder': binder,
        'inspector': inspector,
        'base_style_ref': baseStyleRef,
        'page_width': pageWidth,
        'theme': theme,
        'compute_count_on_close_session': computeCountOnCloseSession,
      };

  @override
  int get hashCode => Object.hash(
        binder,
        inspector,
        baseStyleRef,
        pageWidth,
        theme,
        computeCountOnCloseSession,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorPreferences &&
          runtimeType == other.runtimeType &&
          binder == other.binder &&
          inspector == other.inspector &&
          baseStyleRef == other.baseStyleRef &&
          pageWidth == other.pageWidth &&
          theme == other.theme &&
          computeCountOnCloseSession == other.computeCountOnCloseSession;
}

/// Book/publication metadata (`book` block): title-page and bibliographic info
/// used when compiling (PDF/LaTeX/EPUB) and by the placeholder rules
/// (`<$projecttitle>`, `<$abbr_title>`, `<$iscode>`).
class Book {
  /// Book title shown on the title page (`<$projecttitle>`).
  final String title;

  /// Short/abbreviated title for running headers (`<$abbr_title>`).
  final String abbreviatedTitle;

  /// ISBN shown on the copyright page (`<$iscode>`).
  final String isbn;

  final String subject;
  final String company;
  final String copyright;
  final String keywords;
  final String comments;

  const Book({
    this.title = '',
    this.abbreviatedTitle = '',
    this.isbn = '',
    this.subject = '',
    this.company = '',
    this.copyright = '',
    this.keywords = '',
    this.comments = '',
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        title: json['title'] as String? ?? '',
        abbreviatedTitle: json['abbreviated_title'] as String? ?? '',
        isbn: json['isbn'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        company: json['company'] as String? ?? '',
        copyright: json['copyright'] as String? ?? '',
        keywords: json['keywords'] as String? ?? '',
        comments: json['comments'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'abbreviated_title': abbreviatedTitle,
        'isbn': isbn,
        'subject': subject,
        'company': company,
        'copyright': copyright,
        'keywords': keywords,
        'comments': comments,
      };

  @override
  int get hashCode => Object.hash(
        title,
        abbreviatedTitle,
        isbn,
        subject,
        company,
        copyright,
        keywords,
        comments,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          abbreviatedTitle == other.abbreviatedTitle &&
          isbn == other.isbn &&
          subject == other.subject &&
          company == other.company &&
          copyright == other.copyright &&
          keywords == other.keywords &&
          comments == other.comments;
}

/// Global project metadata (`files/metadata.json`).
class Metadata {
  final int? schemaVersion;
  final ProjectInfo project;
  final Author author;
  final Book book;
  final CompileDefaults compileDefaults;
  final EditorPreferences editorPreferences;
  final SessionState session;
  final Statistics statistics;

  const Metadata({
    this.schemaVersion = kCurrentSchemaVersion,
    required this.project,
    required this.author,
    required this.book,
    required this.compileDefaults,
    required this.editorPreferences,
    required this.session,
    required this.statistics,
  });

  const Metadata.empty({
    this.schemaVersion = kCurrentSchemaVersion,
    this.project = const ProjectInfo(),
    this.author = const Author(),
    this.book = const Book(),
    this.compileDefaults = const CompileDefaults(),
    this.editorPreferences = const EditorPreferences(),
    this.session = const SessionState(),
    this.statistics = const Statistics(),
  });

  factory Metadata.fromJson(Map<String, dynamic> json) => Metadata(
        schemaVersion: json['schema_version'] as int?,
        project: ProjectInfo.fromJson(
            json['project'] as Map<String, dynamic>? ?? {}),
        author: Author.fromMap(json['author'] as Map<String, dynamic>? ?? {}),
        book: Book.fromJson(json['book'] as Map<String, dynamic>? ?? {}),
        compileDefaults: CompileDefaults.fromJson(
            json['compile_defaults'] as Map<String, dynamic>? ?? {}),
        editorPreferences: EditorPreferences.fromJson(
            json['editor_preferences'] as Map<String, dynamic>? ?? {}),
        session: SessionState.fromJson(
            json['session'] as Map<String, dynamic>? ?? {}),
        statistics: Statistics.fromJson(
            json['statistics'] as Map<String, dynamic>? ?? {}),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (schemaVersion != null) 'schema_version': schemaVersion,
        'project': project.toJson(),
        'author': author.toMap(),
        'book': book.toJson(),
        'compile_defaults': compileDefaults.toJson(),
        'editor_preferences': editorPreferences.toJson(),
        'session': session.toJson(),
        'statistics': statistics.toJson(),
      };

  Metadata copyWith({
    ProjectInfo? project,
    Author? author,
    Book? book,
    CompileDefaults? compileDefaults,
    EditorPreferences? editorPreferences,
    SessionState? session,
    Statistics? statistics,
  }) {
    return Metadata(
      schemaVersion: schemaVersion,
      project: project ?? this.project,
      author: author ?? this.author,
      book: book ?? this.book,
      compileDefaults: compileDefaults ?? this.compileDefaults,
      editorPreferences: editorPreferences ?? this.editorPreferences,
      session: session ?? this.session,
      statistics: statistics ?? this.statistics,
    );
  }

  /// Convenience that only swaps the statistics block.
  Metadata copyWithStatistics(Statistics statistics) {
    return copyWith(statistics: statistics);
  }

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        project,
        author,
        book,
        compileDefaults,
        editorPreferences,
        session,
        statistics,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Metadata &&
          runtimeType == other.runtimeType &&
          schemaVersion == other.schemaVersion &&
          project == other.project &&
          author == other.author &&
          book == other.book &&
          compileDefaults == other.compileDefaults &&
          editorPreferences == other.editorPreferences &&
          session == other.session &&
          statistics == other.statistics;
}

/// The `project` block: identity, timestamps and cosmetic settings.
class ProjectInfo {
  final String id;
  final String name;
  final int version;
  final List<String> revisions;
  final String synopsis;
  final String path;
  final String language;

  /// `<image>|<color>` — either an image path/url or a hex/rgb/rgba color.
  final String background;

  /// `<image>` cover, or `null`.
  final String? cover;
  final String createdAt;
  final String updatedAt;

  const ProjectInfo({
    this.id = '',
    this.name = '',
    this.version = 0,
    this.revisions = const <String>[],
    this.synopsis = '',
    this.path = '',
    this.language = '',
    this.background = '',
    this.cover,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory ProjectInfo.fromJson(Map<String, dynamic> json) => ProjectInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        version: json['version'] as int? ?? 0,
        revisions:
            (json['revisions'] as List?)?.cast<String>() ?? const <String>[],
        synopsis: json['synopsis'] as String? ?? '',
        path: json['path'] as String? ?? '',
        language: json['language'] as String? ?? '',
        background: json['background'] as String? ?? '',
        cover: json['cover'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'version': version,
        'revisions': revisions,
        'synopsis': synopsis,
        'path': path,
        'language': language,
        'background': background,
        if (cover != null) 'cover': cover,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  ProjectInfo copyWith({
    String? name,
    int? version,
    List<String>? revisions,
    String? synopsis,
    String? background,
    String? cover,
    String? updatedAt,
  }) {
    return ProjectInfo(
      id: id,
      name: name ?? this.name,
      version: version ?? this.version,
      revisions: revisions ?? this.revisions,
      synopsis: synopsis ?? this.synopsis,
      path: path,
      language: language,
      background: background ?? this.background,
      cover: cover ?? this.cover,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  int get hashCode => Object.hash(id, name, version, Object.hashAll(revisions),
      synopsis, path, language, background, cover, createdAt, updatedAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          version == other.version &&
          listEquals(revisions, other.revisions) &&
          synopsis == other.synopsis &&
          path == other.path &&
          language == other.language &&
          background == other.background &&
          cover == other.cover &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;
}

/// State of the last editing session.
class SessionState {
  final String? lastOpenedDocument;
  final String? lastOpenedAt;
  final List<String> binderExpandedNodes;
  final String activeView;
  final double splitRatio;
  final bool corkboardVisible;

  const SessionState({
    this.lastOpenedDocument,
    this.lastOpenedAt,
    this.binderExpandedNodes = const <String>[],
    this.activeView = '',
    this.splitRatio = 0.0,
    this.corkboardVisible = false,
  });

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
        lastOpenedDocument: json['last_opened_document'] as String?,
        lastOpenedAt: json['last_opened_at'] as String?,
        binderExpandedNodes:
            (json['binder_expanded_nodes'] as List?)?.cast<String>() ??
                const <String>[],
        activeView: json['active_view'] as String? ?? '',
        splitRatio: (json['split_ratio'] as num?)?.toDouble() ?? 0.0,
        corkboardVisible: json['corkboard_visible'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (lastOpenedDocument != null)
          'last_opened_document': lastOpenedDocument,
        if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
        'binder_expanded_nodes': binderExpandedNodes,
        'active_view': activeView,
        'split_ratio': splitRatio,
        'corkboard_visible': corkboardVisible,
      };

  @override
  int get hashCode => Object.hash(
      lastOpenedDocument,
      lastOpenedAt,
      Object.hashAll(binderExpandedNodes),
      activeView,
      splitRatio,
      corkboardVisible);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState &&
          runtimeType == other.runtimeType &&
          lastOpenedDocument == other.lastOpenedDocument &&
          lastOpenedAt == other.lastOpenedAt &&
          listEquals(binderExpandedNodes, other.binderExpandedNodes) &&
          activeView == other.activeView &&
          splitRatio == other.splitRatio &&
          corkboardVisible == other.corkboardVisible;
}

/// Aggregated word/character statistics.
class Statistics {
  final int totalDocuments;
  final int totalFolders;
  final int totalExternalFiles;
  final int totalWordCount;
  final int manuscriptWordCount;
  final int researchWordCount;
  final int trashWordCount;

  const Statistics({
    this.totalDocuments = 0,
    this.totalFolders = 0,
    this.totalExternalFiles = 0,
    this.totalWordCount = 0,
    this.manuscriptWordCount = 0,
    this.researchWordCount = 0,
    this.trashWordCount = 0,
  });

  factory Statistics.fromJson(Map<String, dynamic> json) => Statistics(
        totalDocuments: json['total_documents'] as int? ?? 0,
        totalFolders: json['total_folders'] as int? ?? 0,
        totalExternalFiles: json['total_external_files'] as int? ?? 0,
        totalWordCount: json['total_word_count'] as int? ?? 0,
        manuscriptWordCount: json['manuscript_word_count'] as int? ?? 0,
        researchWordCount: json['research_word_count'] as int? ?? 0,
        trashWordCount: json['trash_word_count'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'total_documents': totalDocuments,
        'total_folders': totalFolders,
        'total_external_files': totalExternalFiles,
        'total_word_count': totalWordCount,
        'manuscript_word_count': manuscriptWordCount,
        'research_word_count': researchWordCount,
        'trash_word_count': trashWordCount,
      };

  @override
  int get hashCode => Object.hash(
      totalDocuments,
      totalFolders,
      totalExternalFiles,
      totalWordCount,
      manuscriptWordCount,
      researchWordCount,
      trashWordCount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Statistics &&
          runtimeType == other.runtimeType &&
          totalDocuments == other.totalDocuments &&
          totalFolders == other.totalFolders &&
          totalExternalFiles == other.totalExternalFiles &&
          totalWordCount == other.totalWordCount &&
          manuscriptWordCount == other.manuscriptWordCount &&
          researchWordCount == other.researchWordCount &&
          trashWordCount == other.trashWordCount;
}
