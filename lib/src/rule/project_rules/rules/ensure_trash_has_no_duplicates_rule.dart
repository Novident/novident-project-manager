import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_document_format/novident_document_format.dart';

import '../project_rule_mixin.dart';
import '../project_status_response.dart';

final class EnsureTrashHasNoDuplicatesRule with ProjectRule {
  const EnsureTrashHasNoDuplicatesRule();

  @override
  ProjectStatusResponse isValid(Folder root) {
    final Iterable<Folder> nodes = root
        .collectNodes(
          shouldGetNode: (Node node) =>
              node is Folder && node.type == FolderType.trash,
          deep: true,
        )
        .cast<Folder>();
    final bool isValid = nodes.length == 1;
    return ProjectStatusResponse(
        isValid: isValid,
        failReason: isValid
            ? null
            : 'The current project has more than one(${nodes.length})'
                'trash folder that it should have'
                'already. This is not a valid '
                'project to be imported/export');
  }
}
