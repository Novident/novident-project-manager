import 'dart:convert';

import 'package:novident_project_manager/src/schema/registry.dart';

/// Record of a performed compilation export (`compiler/exports/<id>.json`).
///
/// An export **record** is not the produced file (which lives outside the
/// project) and not the [Format] used to compile it (see
/// `compiler/formats/`). It documents one run: which format was used, which
/// output type was produced, with which options and when. The UI can use it to
/// list past exports, reproduce one (“export again”) or delete it.
class Export {
  /// Schema version of the record file.
  final int? schemaVersion;

  /// Unique id of the record (the file name key).
  final String id;

  /// Human-readable name shown in the exports list.
  final String name;

  /// Id of the format used to compile (`compiler/formats/<id>.json`).
  final String formatId;

  /// Output type of the produced file (`pdf`, `docx`, `epub`, `latex`, …).
  final String outputType;

  /// ISO timestamp of the last run, or `null` when the record was created but
  /// not run yet.
  final String? lastExported;

  /// Options used for that run (title page, TOC, fonts, quality, …).
  final ExportConfig config;

  const Export({
    this.schemaVersion = kCurrentSchemaVersion,
    this.id = '',
    this.name = '',
    this.formatId = '',
    this.outputType = '',
    this.lastExported,
    this.config = const ExportConfig(),
  });

  factory Export.fromJson(Map<String, dynamic> json) => Export(
        schemaVersion: json['schema_version'] as int?,
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        formatId: json['format_id'] as String? ?? '',
        outputType: json['output_type'] as String? ?? '',
        lastExported: json['last_exported'] as String?,
        config: ExportConfig.fromJson(
            json['config'] as Map<String, dynamic>? ?? const {}),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (schemaVersion != null) 'schema_version': schemaVersion,
        'id': id,
        'name': name,
        'format_id': formatId,
        'output_type': outputType,
        'last_exported': lastExported,
        'config': config.toJson(),
      };

  String toJsonString() => json.encode(toJson());

  factory Export.fromJsonString(String source) =>
      Export.fromJson(json.decode(source) as Map<String, dynamic>);
}

/// Options of an export run.
class ExportConfig {
  /// Whether the output includes a title page.
  final bool includeTitlePage;

  /// Whether the output includes a table of contents.
  final bool includeToc;

  /// Whether the output includes the copyright page.
  final bool includeCopyright;

  /// Whether fonts are embedded in the produced file.
  final bool embedFonts;

  /// Image quality used for embedded images (0–100).
  final int imageQuality;

  const ExportConfig({
    this.includeTitlePage = false,
    this.includeToc = false,
    this.includeCopyright = false,
    this.embedFonts = false,
    this.imageQuality = 0,
  });

  factory ExportConfig.fromJson(Map<String, dynamic> json) => ExportConfig(
        includeTitlePage: json['include_title_page'] as bool? ?? false,
        includeToc: json['include_toc'] as bool? ?? false,
        includeCopyright: json['include_copyright'] as bool? ?? false,
        embedFonts: json['embed_fonts'] as bool? ?? false,
        imageQuality: json['image_quality'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'include_title_page': includeTitlePage,
        'include_toc': includeToc,
        'include_copyright': includeCopyright,
        'embed_fonts': embedFonts,
        'image_quality': imageQuality,
      };
}
