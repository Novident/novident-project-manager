import 'dart:convert';

import 'package:novident_project_manager/src/schema/registry.dart';

/// Writing targets, global and per node (`indexation/target.index.json`).
///
/// `general` holds the project-wide goal; `files` holds optional per-node
/// overrides keyed by binder node id.
class TargetIndex {
  final int? schemaVersion;
  final TargetGeneral general;
  final Map<String, TargetFile> files;

  const TargetIndex({
    this.schemaVersion = kCurrentSchemaVersion,
    this.general = const TargetGeneral(),
    this.files = const <String, TargetFile>{},
  });

  factory TargetIndex.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    return TargetIndex(
      schemaVersion: json['schema_version'] as int?,
      general: TargetGeneral.fromJson(
          json['general'] as Map<String, dynamic>? ?? const {}),
      files: rawFiles is Map<String, dynamic>
          ? rawFiles.map((String id, dynamic value) => MapEntry(
              id, TargetFile.fromJson(value as Map<String, dynamic>)))
          : const <String, TargetFile>{},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (schemaVersion != null) 'schema_version': schemaVersion,
        'general': general.toJson(),
        'files': files.map(
            (String id, TargetFile file) => MapEntry(id, file.toJson())),
      };

  String toJsonString() => json.encode(toJson());

  factory TargetIndex.fromJsonString(String source) =>
      TargetIndex.fromJson(json.decode(source) as Map<String, dynamic>);

  TargetIndex copyWith({
    int? schemaVersion,
    TargetGeneral? general,
    Map<String, TargetFile>? files,
  }) {
    return TargetIndex(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      general: general ?? this.general,
      files: files ?? this.files,
    );
  }

  /// Replaces the project-wide goal.
  TargetIndex updateGeneral(TargetGeneral value) => copyWith(general: value);

  /// Adds or replaces the per-node target of [nodeId].
  TargetIndex setOverride(String nodeId, TargetFile target) =>
      copyWith(files: <String, TargetFile>{...files, nodeId: target});

  /// Removes the per-node target of [nodeId] (no-op when none is set).
  TargetIndex removeOverride(String nodeId) {
    if (!files.containsKey(nodeId)) return this;
    final Map<String, TargetFile> updated = Map<String, TargetFile>.of(files);
    updated.remove(nodeId);
    return copyWith(files: updated);
  }
}

/// Project-wide goal, reused by `history/` to measure distance to the target.
class TargetGeneral {
  final String typeTarget;
  final int target;
  final int targetCharacters;
  final String? deadline;
  final String genre;
  final String subgenre;
  final String audience;
  final int targetWordCount;
  final int currentWordCount;
  final String language;

  const TargetGeneral({
    this.typeTarget = '',
    this.target = 0,
    this.targetCharacters = 0,
    this.deadline,
    this.genre = '',
    this.subgenre = '',
    this.audience = '',
    this.targetWordCount = 0,
    this.currentWordCount = 0,
    this.language = '',
  });

  factory TargetGeneral.fromJson(Map<String, dynamic> json) => TargetGeneral(
        typeTarget: json['type_target'] as String? ?? '',
        target: json['target'] as int? ?? 0,
        targetCharacters: json['target_characters'] as int? ?? 0,
        deadline: json['deadline'] as String?,
        genre: json['genre'] as String? ?? '',
        subgenre: json['subgenre'] as String? ?? '',
        audience: json['audience'] as String? ?? '',
        targetWordCount: json['target_word_count'] as int? ?? 0,
        currentWordCount: json['current_word_count'] as int? ?? 0,
        language: json['language'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type_target': typeTarget,
        'target': target,
        'target_characters': targetCharacters,
        if (deadline != null) 'deadline': deadline,
        'genre': genre,
        'subgenre': subgenre,
        'audience': audience,
        'target_word_count': targetWordCount,
        'current_word_count': currentWordCount,
        'language': language,
      };
}

class TargetFile {
  final bool notify;
  final String? deadline;
  final int words;
  final int characters;

  const TargetFile({
    this.notify = false,
    this.deadline,
    this.words = 0,
    this.characters = 0,
  });

  factory TargetFile.fromJson(Map<String, dynamic> json) => TargetFile(
        notify: json['notify'] as bool? ?? false,
        deadline: json['deadline'] as String?,
        words: json['words'] as int? ?? 0,
        characters: json['characters'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'notify': notify,
        if (deadline != null) 'deadline': deadline,
        'words': words,
        'characters': characters,
      };
}
