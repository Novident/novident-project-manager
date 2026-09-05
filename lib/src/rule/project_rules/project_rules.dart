import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_project_manager/src/rule/project_rules/project_rule_mixin.dart';
import 'package:novident_project_manager/src/rule/project_rules/project_status_response.dart';
import 'package:novident_project_manager/src/rule/project_rules/rules/ensure_manuscript_existence_rule.dart';
import 'package:novident_project_manager/src/rule/project_rules/rules/ensure_research_existence_rule.dart';
import 'package:novident_project_manager/src/rule/project_rules/rules/ensure_trash_folder_existence_rule.dart';
import 'package:novident_project_manager/src/rule/project_rules/rules/ensure_trash_has_no_duplicates_rule.dart';
import 'package:novident_project_manager/src/rule/project_rules/rules/ensure_trashed_files_are_in_trash_rule.dart';

import '../../exceptions/bad_project_state_exception.dart';

/// All the rules that must run every time we import or export a project.
///
/// These rules ensure the imported/exported project has the correct values,
/// structure, content and current standards.
class ProjectRules {
  const ProjectRules._();

  static final List<ProjectRule> _rules = <ProjectRule>[
    // Novident has three default root folders which cannot be deleted or moved
    // from the top level: Draft/Manuscript, Research and Trash.
    EnsureTrashFolderExistenceRule(),
    EnsureManuscriptExistenceRule(),
    EnsureResearchExistenceRule(),
    // Common rules.
    EnsureTrashedNodesAreIntoTrashRule(),
    EnsureTrashHasNoDuplicatesRule(),
  ];

  /// Runs every rule against [root]; throws [BadProjectStateException] with
  /// the first failing reason, or returns `true` when the project is valid.
  static bool checkProjectState(Folder root) {
    for (final ProjectRule rule in _rules) {
      final ProjectStatusResponse response = rule.isValid(root);
      if (!response.isValid) {
        throw BadProjectStateException(reason: response.failReason!);
      }
    }
    return true;
  }
}
