import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_document_format/novident_document_format.dart';

import '../project_rule_mixin.dart';
import '../project_status_response.dart';

final class EnsureResearchExistenceRule with ProjectRule {
  const EnsureResearchExistenceRule();

  @override
  ProjectStatusResponse isValid(Folder root) {
    final Node? research = root.visitNode(
      shouldGetNode: (Node node) =>
          node is Folder && node.type == FolderType.research,
    );
    final bool isValid = research != null && research.isAtRootLevel;
    return ProjectStatusResponse(
      isValid: isValid,
      failReason: isValid
          ? null
          : 'Research folder was not founded at any '
              'point of the Project. This has not the correct '
              'structure and we cannot '
              'import/export it as expected.',
    );
  }
}
