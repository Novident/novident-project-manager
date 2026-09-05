import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_document_format/novident_document_format.dart';

/// Builds a well-formed binder root: optional [rootNodes] plus the three
/// special folders (Manuscript, Research and Trash), with optional
/// [manuscriptChildren] inside Manuscript.
Folder generateBasicProject({
  List<Node>? manuscriptChildren,
  List<Node>? rootNodes,
}) {
  return Folder(
    name: 'root',
    details: NodeDetails.byId(level: -1, id: 'root'),
    children: <Node>[
      ...?rootNodes,
      Folder(
        name: 'Manuscript',
        folderType: FolderType.manuscript,
        children: <Node>[...?manuscriptChildren],
        details: NodeDetails.zero(),
      ),
      Folder(
        name: 'Research',
        folderType: FolderType.research,
        children: <Node>[],
        details: NodeDetails.zero(),
      ),
      Folder(
        children: <Node>[],
        name: 'Trash',
        folderType: FolderType.trash,
        details: NodeDetails.zero(),
      ),
    ],
  );
}
