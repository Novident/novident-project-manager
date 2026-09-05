import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_document_format/novident_document_format.dart';

import '../project_rule_mixin.dart';
import '../project_status_response.dart';

final class EnsureManuscriptExistenceRule with ProjectRule {
  const EnsureManuscriptExistenceRule();

  @override
  ProjectStatusResponse isValid(Folder root) {
    final Node? manuscript = root.visitNode(
      shouldGetNode: (Node node) =>
          node is Folder && node.type == FolderType.manuscript,
    );
    final bool isValid = manuscript != null && manuscript.isAtRootLevel;
    return ProjectStatusResponse(
      isValid: isValid,
      failReason: isValid
          ? null
          : 'Manuscript folder was not founded at any '
              'point of the Project. This has not the correct '
              'structure and we cannot '
              'import/export it as expected.',
    );
  }
}
