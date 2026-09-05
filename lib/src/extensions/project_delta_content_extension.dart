import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_project_manager/src/rule/placeholder/placeholder_rules.dart';

import '../constants/constants.dart';
import '../layout/processor_context.dart';
import '../rule/placeholder/type_placeholder_enum.dart';

/// Convenience extension that lets a compilation [Document] replace its
/// placeholder tokens (`<$projecttitle>`, `<$n>`, `<$page>`, dates, …) using
/// the placeholder rules configured for the project.
///
/// Each method targets one family of placeholders ([TypePlaceholder]); the
/// defaults come from [NovidentConstants.kDefaultPlaceholderRules].
extension ProjectDeltaContentExtension on Document {
  /// Replaces every common project placeholder token in the document.
  ///
  /// Applies all rules of [TypePlaceholder.all] using the values exposed by
  /// [context] (project data, counts, …). Returns a new [Document]; the
  /// receiver is not modified.
  Document replacePlaceholders(
    Context context, {
    PlaceholderRules rules = NovidentConstants.kDefaultPlaceholderRules,
  }) {
    return rules.applyRules(
      this,
      TypePlaceholder.all,
      context,
    );
  }

  /// Replaces index placeholders (`<$n>`, counts, …) in the document.
  ///
  /// Only the rules of [TypePlaceholder.indexes] are applied against [context].
  /// Returns a new [Document]; the receiver is not modified.
  Document replaceIndexKeys(
    Context context, {
    PlaceholderRules rules = NovidentConstants.kDefaultPlaceholderRules,
  }) {
    return rules.applyRules(
      this,
      TypePlaceholder.indexes,
      context,
    );
  }

  /// Replaces project placeholders (`<$projecttitle>`, author data, …) in the
  /// document.
  ///
  /// Only the rules of [TypePlaceholder.projectInfo] are applied. The [name]
  /// argument is accepted for API symmetry with the other families; the actual
  /// values are resolved from [context]. Returns a new [Document]; the receiver
  /// is not modified.
  Document replaceProjectKeys(
    String name,
    Context context, {
    PlaceholderRules rules = NovidentConstants.kDefaultPlaceholderRules,
  }) {
    return rules.applyRules(
      this,
      TypePlaceholder.projectInfo,
      context,
    );
  }

  /// Replaces date placeholders in the document.
  ///
  /// Only the rules of [TypePlaceholder.dates] are applied against [context].
  /// Returns a new [Document]; the receiver is not modified.
  Document replaceDateKeys(
    Context context, {
    PlaceholderRules rules = NovidentConstants.kDefaultPlaceholderRules,
  }) {
    return rules.applyRules(
      this,
      TypePlaceholder.dates,
      context,
    );
  }

  // TODO: replace this whole-document rewrite with an editor-aware transform
  // that preserves non-text operations (kept for reference while the delta
  // attribute override is reworked).
  // Delta overrideAttributes(
  //   Delta delta,
  //   Map<String, dynamic> inline,
  // ) {
  //   final Delta newDelta = Delta();
  //   for (int index = 0; index < delta.operations.length; index++) {
  //     final TextOperation op = delta.operations[index];
  //     if (op is! TextInsert) {
  //       continue;
  //     }
  //     // Ignore any new line
  //     if (op.data == '\n') {
  //       continue;
  //     }
  //     newDelta.insert(
  //       op.data.cast<String>()!,
  //       attributes: inline,
  //     );
  //   }
  //   return newDelta;
  // }
}
