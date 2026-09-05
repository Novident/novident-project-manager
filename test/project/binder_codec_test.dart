import 'package:flutter_test/flutter_test.dart';
import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_project_manager/src/project/binder_codec.dart';

Folder _buildTree() {
  final manuscript = Folder(
    children: <Node>[
      Document(
        details: NodeDetails.byId(level: 0, id: 'doc-1'),
        name: 'Chapter 1',
        attachedSection: 'scene',
      ),
      DocumentResource(
        details: NodeDetails.byId(level: 0, id: 'res-1'),
        name: 'map',
        extension: 'png',
        path: 'files/external/res-1.png',
      ),
    ],
    name: 'Draft',
    details: NodeDetails.byId(level: 0, id: 'folder-manuscript'),
    folderType: FolderType.manuscript,
  );

  final trash = Folder(
    children: <Node>[
      Document(
        details: NodeDetails.byId(level: 0, id: 'doc-trashed'),
        name: 'Old scene',
        trashOptions: const NodeTrashedOptions(isTrashed: true, expire: null),
      ),
    ],
    name: 'Trash',
    details: NodeDetails.byId(level: 0, id: 'folder-trash'),
    folderType: FolderType.trash,
  );

  return Folder(
    children: <Node>[manuscript, trash],
    name: 'Root',
    details: NodeDetails.base('project-1'),
  );
}

void main() {
  group('BinderCodec', () {
    test('roundtrips folder/document hierarchy', () {
      final encoded = BinderCodec.encode(
        projectId: 'project-1',
        projectName: 'Test Novel',
        root: _buildTree(),
      );
      final decoded = BinderCodec.decode(encoded);

      expect(decoded.projectId, 'project-1');
      expect(decoded.projectName, 'Test Novel');
      expect(decoded.root.id, 'project-1');
      expect(decoded.root.children.length, 2);

      final manuscript = decoded.root.children[0] as Folder;
      expect(manuscript.id, 'folder-manuscript');
      expect(manuscript.name, 'Draft');
      expect(manuscript.folderType, FolderType.manuscript);
      expect(manuscript.children.length, 2);

      final doc = manuscript.children[0] as Document;
      expect(doc.id, 'doc-1');
      expect(doc.name, 'Chapter 1');
      expect(doc.attachedSection, 'scene');

      final resource = manuscript.children[1] as DocumentResource;
      expect(resource.id, 'res-1');
      expect(resource.extension, 'png');

      final trash = decoded.root.children[1] as Folder;
      expect(trash.folderType, FolderType.trash);
      final trashedDoc = trash.children[0] as Document;
      expect(trashedDoc.trashStatus.isTrashed, isTrue);
    });

    test('emits tree, lookup and external_files', () {
      final encoded = BinderCodec.encode(
        projectId: 'project-1',
        projectName: 'Test Novel',
        root: _buildTree(),
      );

      final tree = encoded['tree'] as List;
      expect(tree.length, 2);

      final lookup = encoded['lookup'] as Map<String, dynamic>;
      expect(lookup.containsKey('folder-manuscript'), isTrue);
      expect(lookup.containsKey('doc-1'), isTrue);
      expect(lookup['doc-1']['parent_id'], 'folder-manuscript');

      final externalFiles =
          encoded['external_files'] as Map<String, dynamic>;
      expect(externalFiles.containsKey('res-1'), isTrue);
      expect(externalFiles['res-1']['attached_to'], 'folder-manuscript');

      final manuscriptNode = tree[0] as Map<String, dynamic>;
      expect(manuscriptNode['folder_type'], 'manuscript');
      expect(manuscriptNode['resources'], <String>['res-1']);
    });

    test('decode handles missing/empty binder gracefully', () {
      final decoded = BinderCodec.decode(const <String, dynamic>{});
      expect(decoded.projectId, '');
      expect(decoded.projectName, '');
      expect(decoded.root.children, isEmpty);
    });
  });
}
