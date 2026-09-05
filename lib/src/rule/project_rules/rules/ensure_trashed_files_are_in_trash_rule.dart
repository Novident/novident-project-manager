import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_document_format/novident_document_format.dart';

import '../../../extensions/cast_extension.dart';
import '../project_rule_mixin.dart';
import '../project_status_response.dart';

final class EnsureTrashedNodesAreIntoTrashRule with ProjectRule {
  const EnsureTrashedNodesAreIntoTrashRule();

  @override
  ProjectStatusResponse isValid(Folder root) {
    final Iterable<Node> trashedFiles = root.whereDeep((Node node) {
      return node is! Folder ||
          !node.type.isNotTrashFolder && node.trashStatus.isTrashed;
    });
    final bool isValid = trashedFiles.isEmpty;
    return ProjectStatusResponse(
      isValid: isValid,
      failReason: isValid
          ? null
          : 'Trash files were founded outside of '
              'the Trash folder. This error cannot let us '
              'import/export correctly the project, since it does not '
              'satify the Novident project Stantard.\n'
              'The files founded are: ${trashedFiles.map(
              (Node e) => e.cast<UniversalName>().objectName,
            )}',
    );
  }
}
