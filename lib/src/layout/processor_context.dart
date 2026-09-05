import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_editor_styles/novident_editor_styles.dart';

import '../format/replacement_values.dart';
import '../project/author/author.dart';
import '../project/processor_metadata.dart';

abstract class Context<T> {
  List<DocumentResource> resources;
  Map<String, int> documentVariables;
  bool shouldWritePageOptions;
  Document? currentDocument;
  bool processPlaceholderAtEnd;
  DateTime? time;
  int? runningCompileOnLevel;
  bool releaseBuffer;
  bool releaseNodesQueue;

  /// If the rules are disabled
  /// then this will take that value
  /// and avoid replace the placeholders
  bool placeholderDisabled;

  /// this is the project name that the user
  /// has, and not the version that is passed
  /// to the metadata of the project
  String rawProjectName;
  String language;
  int charsCount;
  int wordsCount;
  int linecount;
  ReplacementsValues? customPatterns;
  Author author;
  ProjectMetadata metadata;

  NovidentStyleDefinition? getStyle(String id);
  UniversalValue<T> getNodeContent(String id);
  UniversalValue<R> getNodeComment<R>(String id);
  UniversalValue<R> getNodeSynopsis<R>(String id);
  UniversalValue<R> getNodeNotes<R>(String id);

  /// this is a way that must be defined when the Context is created
  ///
  /// is useful when we need to get a document and, we just have a name or id
  Document? Function(String name) jumpToDocument;

  DocumentResource? queryResource(String resourceName);
  Context regenerateContext();

  Context({
    required this.resources,
    required this.documentVariables,
    required this.shouldWritePageOptions,
    required this.currentDocument,
    required this.processPlaceholderAtEnd,
    required this.time,
    required this.runningCompileOnLevel,
    required this.releaseBuffer,
    required this.releaseNodesQueue,
    required this.placeholderDisabled,
    required this.rawProjectName,
    required this.language,
    required this.charsCount,
    required this.wordsCount,
    required this.linecount,
    required this.customPatterns,
    required this.author,
    required this.metadata,
    required this.jumpToDocument,
  });

}
