import 'package:flutter_test/flutter_test.dart';
import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_project_manager/src/reducer/binder_actions.dart';
import 'package:novident_project_manager/src/reducer/binder_counts.dart';

/// root (normal)
///   ├── Draft (manuscript)
///   │     ├── d1
///   │     └── sub (normal) └── d2
///   ├── Research (research) └── d3
///   ├── Templates (templatesSheet)
///   ├── Trash (trash) └── d4 (trashed)
///   └── loose (normal) └── d5
Folder buildRoot() {
  final Folder draft = Folder(
    children: <Node>[
      Document(details: NodeDetails.byId(level: 2, id: 'd1'), name: 'A'),
      Folder(
        children: <Node>[
          Document(details: NodeDetails.byId(level: 3, id: 'd2'), name: 'B'),
        ],
        details: NodeDetails.byId(level: 2, id: 'sub'),
        name: 'Sub',
      ),
    ],
    details: NodeDetails.byId(level: 1, id: 'draft'),
    name: 'Draft',
    folderType: FolderType.manuscript,
  );
  final Folder research = Folder(
    children: <Node>[
      Document(details: NodeDetails.byId(level: 2, id: 'd3'), name: 'C'),
    ],
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
    children: <Node>[
      Document(
        details: NodeDetails.byId(level: 2, id: 'd4'),
        name: 'Old',
        trashOptions: NodeTrashedOptions.now(),
      ),
    ],
    details: NodeDetails.byId(level: 1, id: 'trash'),
    name: 'Trash',
    folderType: FolderType.trash,
  );
  final Folder loose = Folder(
    children: <Node>[
      Document(details: NodeDetails.byId(level: 2, id: 'd5'), name: 'Loose'),
    ],
    details: NodeDetails.byId(level: 1, id: 'loose'),
    name: 'Loose',
  );
  return Folder(
    children: <Node>[draft, research, templates, trash, loose],
    name: 'Project',
    details: NodeDetails.byId(level: 0, id: 'root'),
  );
}

void main() {
  test('counts documents by their tree region', () {
    final NodeCounts counts = BinderCounts.compute(buildRoot());

    // d1, d2, d3, d4 (trashed), d5.
    expect(counts.totalDocuments, 5);
    // draft + sub + research + templates + trash + loose.
    expect(counts.totalFolders, 6);
    // d1 + d2 under manuscript; d3 under research; d4 trashed; d5 loose.
    expect(counts.manuscriptDocuments, 2);
    expect(counts.researchDocuments, 1);
    expect(counts.trashDocuments, 1);
  });

  test('computeWords sums measured words by region', () {
    final Folder root = buildRoot();
    final WordCounts words = BinderCounts.computeWords(root, <String, int>{
      'd1': 100, // manuscript
      'd2': 50, // manuscript (nested in sub)
      'd3': 30, // research
      'd4': 10, // trash
      'd5': 20, // loose (normal → only total)
    });

    expect(words.manuscriptWords, 150);
    expect(words.researchWords, 30);
    expect(words.trashWords, 10);
    expect(words.totalWords, 210); // manuscript + research + normal + trash
  });

  test('computeWords treats unmeasured documents as zero', () {
    final Folder root = buildRoot();
    final WordCounts words =
        BinderCounts.computeWords(root, <String, int>{'d1': 100});

    expect(words.manuscriptWords, 100);
    expect(words.researchWords, 0);
    expect(words.totalWords, 100);
  });

  test('a document trashed in place counts as trash even inside manuscript',
      () {
    final Folder root = buildRoot();
    // Move d1 into the trash folder through the real trash action.
    BinderActions.trashNode(root, 'd1');

    final NodeCounts counts = BinderCounts.compute(root);
    expect(counts.trashDocuments, 2); // d4 + d1
    expect(counts.manuscriptDocuments, 1); // only d2 remains
  });

  test('empty tree yields zero counts', () {
    final Folder empty = Folder(
      children: <Node>[],
      name: 'Empty',
      details: NodeDetails.byId(level: 0, id: 'root'),
    );
    final NodeCounts counts = BinderCounts.compute(empty);
    expect(counts.totalDocuments, 0);
    expect(counts.totalFolders, 0);
    expect(counts.totalExternalFiles, 0);
    expect(counts.manuscriptDocuments, 0);
    expect(counts.researchDocuments, 0);
    expect(counts.trashDocuments, 0);
  });
}
