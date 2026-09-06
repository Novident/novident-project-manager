import 'package:flutter_test/flutter_test.dart';
import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_project_manager/src/reducer/binder_actions.dart';
import 'package:novident_project_manager/src/exceptions/reducer_exceptions.dart';

/// Builds a small project root:
///
/// - root (normal)
///   - Draft (manuscript)
///     - d1 (document, scene)
///     - sub (normal folder)
///   - Research (research)
///     - d2 (document)
///   - Templates (templatesSheet)
///   - Trash (trash)
Folder buildRoot() {
  final Document d1 = Document(
    details: NodeDetails.byId(level: 2, id: 'd1'),
    name: 'The Awakening',
    attachedSection: 'scene',
  );
  final Document d2 = Document(
    details: NodeDetails.byId(level: 2, id: 'd2'),
    name: 'Research notes',
  );
  final Folder sub = Folder(
    children: <Node>[],
    details: NodeDetails.byId(level: 2, id: 'sub'),
    name: 'Scenes',
  );
  final Folder draft = Folder(
    children: <Node>[d1, sub],
    details: NodeDetails.byId(level: 1, id: 'draft'),
    name: 'Draft',
    folderType: FolderType.manuscript,
  );
  final Folder research = Folder(
    children: <Node>[d2],
    details: NodeDetails.byId(level: 1, id: 'research'),
    name: 'Research',
    folderType: FolderType.research,
  );
  final Folder templates = Folder(
    children: <Node>[],
    details: NodeDetails.byId(level: 1, id: 'templates'),
    name: 'Templates',
    folderType: FolderType.templatesSheet,
  );
  final Folder trash = Folder(
    children: <Node>[],
    details: NodeDetails.byId(level: 1, id: 'trash'),
    name: 'Trash',
    folderType: FolderType.trash,
  );
  return Folder(
    children: <Node>[draft, research, templates, trash],
    name: 'Project',
    details: NodeDetails.byId(level: 0, id: 'root'),
  );
}

void main() {
  test('reads node state through the mixin interfaces', () {
    final Folder root = buildRoot();
    final Node draft = BinderActions.requireNode(root, 'draft');
    final Node d1 = BinderActions.requireNode(root, 'd1');

    expect(BinderActions.nameOf(draft), 'Draft');
    expect(BinderActions.nameOf(d1), 'The Awakening');
    expect(BinderActions.sectionOf(d1), 'scene');
    expect(BinderActions.sectionOf(draft),
        NovidentDefaults.kStructuredBasedSectionId);
    expect(BinderActions.isTrashed(d1), isFalse);
  });

  test('createDocument and createFolder append under a writable folder', () {
    final Folder root = buildRoot();

    final Document doc = BinderActions.createDocument(
      root,
      parentId: 'sub',
      name: 'New scene',
      id: 'nd1',
      section: 'scene',
    );
    final Folder folder = BinderActions.createFolder(
      root,
      parentId: 'sub',
      name: 'Act 1',
      id: 'nf1',
    );

    expect(BinderActions.nameOf(doc), 'New scene');
    expect(BinderActions.sectionOf(doc), 'scene');
    expect(doc.owner?.id, 'sub');
    // The container stores a level-corrected clone; resolve it by id.
    expect(BinderActions.requireNode(root, 'nf1').id, folder.id);
    expect(
        BinderActions.nameOf(BinderActions.requireNode(root, 'nf1')), 'Act 1');
  });

  test('createDocument rejects a non-folder parent and the trash folder', () {
    final Folder root = buildRoot();
    expect(
      () => BinderActions.createDocument(root, parentId: 'd1', name: 'bad'),
      throwsA(isA<NodeTypeException>()),
    );
    expect(
      () => BinderActions.createDocument(root, parentId: 'trash', name: 'bad'),
      throwsA(isA<InvalidParentException>()),
    );
    expect(
      () => BinderActions.requireNode(root, 'missing'),
      throwsA(isA<NodeNotFoundException>()),
    );
  });

  test('renameNode replaces the node keeping its position and type', () {
    final Folder root = buildRoot();

    final Node renamed =
        BinderActions.renameNode(root, 'd1', 'The Reawakening');
    final Folder draft = BinderActions.requireFolder(root, 'draft');

    expect(BinderActions.nameOf(renamed), 'The Reawakening');
    expect(BinderActions.nameOf(draft.children.first), 'The Reawakening');
    expect(draft.children.first.id, 'd1');
  });

  test('setNodeSection updates the section', () {
    final Folder root = buildRoot();
    BinderActions.setNodeSection(root, 'd1', 'chapter');
    expect(BinderActions.sectionOf(BinderActions.requireNode(root, 'd1')),
        'chapter');
  });

  test('moveNode moves between folders and guards cycles', () {
    final Folder root = buildRoot();
    BinderActions.moveNode(root, nodeId: 'd1', targetFolderId: 'research');

    final Node d1 = BinderActions.requireNode(root, 'd1');
    expect(d1.owner?.id, 'research');

    // Moving a folder into one of its own descendants must be rejected.
    expect(
      () =>
          BinderActions.moveNode(root, nodeId: 'draft', targetFolderId: 'sub'),
      throwsA(isA<InvalidMoveException>()),
    );
    // Moving into the trash is only allowed through trashNode.
    expect(
      () => BinderActions.moveNode(root, nodeId: 'd1', targetFolderId: 'trash'),
      throwsA(isA<InvalidMoveException>()),
    );
  });

  test('trashNode moves into the trash and trashes descendants too', () {
    final Folder root = buildRoot();
    // sub holds no documents yet; add one to check recursive trashing.
    BinderActions.createDocument(root,
        parentId: 'sub', name: 'Inside', id: 'nested');
    BinderActions.trashNode(root, 'sub');

    expect(BinderActions.requireNode(root, 'sub').owner?.id, 'trash');
    expect(BinderActions.isTrashed(BinderActions.requireNode(root, 'sub')),
        isTrue);
    expect(BinderActions.isTrashed(BinderActions.requireNode(root, 'nested')),
        isTrue);
  });

  test('trashNode rejects special folders and the root', () {
    final Folder root = buildRoot();
    expect(
      () => BinderActions.trashNode(root, 'draft'),
      throwsA(isA<InvalidParentException>()),
    );
    expect(
      () => BinderActions.trashNode(root, 'trash'),
      throwsA(isA<InvalidParentException>()),
    );
    expect(
      () => BinderActions.trashNode(root, 'root'),
      throwsA(isA<InvalidParentException>()),
    );
  });

  test('restoreNode clears the trashing feature when leaving the trash', () {
    final Folder root = buildRoot();
    BinderActions.trashNode(root, 'd1');
    expect(
        BinderActions.isTrashed(BinderActions.requireNode(root, 'd1')), isTrue);

    // Restoring into the trash itself is not allowed.
    expect(
      () => BinderActions.restoreNode(root, id: 'd1', targetFolderId: 'trash'),
      throwsA(isA<InvalidMoveException>()),
    );

    BinderActions.restoreNode(root, id: 'd1', targetFolderId: 'draft');
    expect(BinderActions.requireNode(root, 'd1').owner?.id, 'draft');
    expect(BinderActions.isTrashed(BinderActions.requireNode(root, 'd1')),
        isFalse);
  });

  test('purgeNode removes the node and returns owned document dirs', () {
    final Folder root = buildRoot();

    // Single document.
    final List<String> docDirs = BinderActions.purgeNode(root, 'd1');
    expect(docDirs, <String>['d1']);
    expect(BinderActions.findNode(root, 'd1'), isNull);

    // Folder: every descendant document dir (sub has no documents).
    final List<String> folderDirs = BinderActions.purgeNode(root, 'draft');
    expect(folderDirs, isEmpty);
    expect(BinderActions.findNode(root, 'draft'), isNull);
    expect(BinderActions.findNode(root, 'sub'), isNull);

    // Root cannot be purged.
    expect(
      () => BinderActions.purgeNode(root, 'root'),
      throwsA(isA<InvalidParentException>()),
    );
  });
}
