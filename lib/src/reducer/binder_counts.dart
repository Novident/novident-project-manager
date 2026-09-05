// ignore_for_file: non_constant_identifier_names

import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_nodes/novident_nodes.dart';

/// Aggregated structural counts computed from the binder tree.
///
/// These feed the `statistics` block of `files/metadata.json`. Word/character
/// counters are computed elsewhere (they require the document content); the
/// reducer recomputes the structural part whenever the tree changes and keeps
/// the word counts it already has.
class NodeCounts {
  const NodeCounts({
    this.totalDocuments = 0,
    this.totalFolders = 0,
    this.totalExternalFiles = 0,
    this.manuscriptDocuments = 0,
    this.researchDocuments = 0,
    this.trashDocuments = 0,
  });

  final int totalDocuments;
  final int totalFolders;
  final int totalExternalFiles;
  final int manuscriptDocuments;
  final int researchDocuments;
  final int trashDocuments;

  static const NodeCounts zero = NodeCounts();
}

/// Word totals grouped by tree region.
///
/// [totalWords] counts **every** document (manuscript + research + normal +
/// trash); the region fields are subsets of it.
class WordCounts {
  const WordCounts({
    this.totalWords = 0,
    this.manuscriptWords = 0,
    this.researchWords = 0,
    this.trashWords = 0,
  });

  final int totalWords;
  final int manuscriptWords;
  final int researchWords;
  final int trashWords;

  static const WordCounts zero = WordCounts();
}

/// The region of the tree a node lives in, for statistics.
///
/// Trash wins over every other region; a normal folder nested under Manuscript
/// stays in the manuscript region.
enum Region { none, manuscript, research, trash, other }

/// Recomputes structural node counts by walking the binder [root] once.
class BinderCounts {
  const BinderCounts._();

  static Region regionOf(Folder folder, Region incoming) {
    if (incoming == Region.trash || folder.type.isTrashFolder) {
      return Region.trash;
    }
    if (folder.type.isManuscriptFolder) return Region.manuscript;
    if (folder.type.isResearchFolder) return Region.research;
    if (folder.type.isTemplatesSheetFolder) return Region.other;
    return incoming;
  }

  static NodeCounts compute(Folder root, {Region? prefer}) {
    int totalDocuments = 0;
    int totalFolders = 0;
    int totalExternalFiles = 0;
    int manuscriptDocuments = 0;
    int researchDocuments = 0;
    int trashDocuments = 0;

    void visit(Node node, Region region) {
      if (node is Folder) {
        totalFolders++;
        final Region next = regionOf(node, region);
        if (next == prefer || prefer == null) {
          for (final Node child in node.children) {
            visit(child, next);
          }
        }
        return;
      }
      if (node is DocumentResource) {
        totalExternalFiles++;
        return;
      }
      if (node is Document) {
        totalDocuments++;
        final bool trashed = region == Region.trash || isTrashedNode(node);
        if (trashed) {
          trashDocuments++;
        } else if (region == Region.manuscript) {
          manuscriptDocuments++;
        } else if (region == Region.research) {
          researchDocuments++;
        }
      }
    }

    for (final Node child in root.children) {
      visit(child, prefer ?? Region.none);
    }

    return NodeCounts(
      totalDocuments: totalDocuments,
      totalFolders: totalFolders,
      totalExternalFiles: totalExternalFiles,
      manuscriptDocuments: manuscriptDocuments,
      researchDocuments: researchDocuments,
      trashDocuments: trashDocuments,
    );
  }

  /// Trash state through the [Trashable] mixin, without depending on the
  /// concrete node type.
  static bool isTrashedNode(Node node) {
    if (node is! Trashable) return false;
    return (node as Trashable).trashStatus.isTrashed;
  }

  /// Sums the measured words of every document by region.
  ///
  /// [wordsById] maps document id → word count (e.g. measured when closing a
  /// session). Documents without a measure contribute zero to their region.
  static WordCounts computeWords(Folder root, Map<String, int> wordsById) {
    int totalWords = 0;
    int manuscriptWords = 0;
    int researchWords = 0;
    int trashWords = 0;

    Region regionOf(Folder folder, Region incoming) {
      if (incoming == Region.trash || folder.type.isTrashFolder) {
        return Region.trash;
      }
      if (folder.type.isManuscriptFolder) return Region.manuscript;
      if (folder.type.isResearchFolder) return Region.research;
      if (folder.type.isTemplatesSheetFolder) return Region.other;
      return incoming;
    }

    void visit(Node node, Region region) {
      if (node is Folder) {
        final Region next = regionOf(node, region);
        for (final Node child in node.children) {
          visit(child, next);
        }
        return;
      }
      if (node is! Document) return;

      final int words = wordsById[node.id] ?? 0;
      totalWords += words;
      if (region == Region.trash || isTrashedNode(node)) {
        trashWords += words;
      } else if (region == Region.manuscript) {
        manuscriptWords += words;
      } else if (region == Region.research) {
        researchWords += words;
      }
    }

    for (final Node child in root.children) {
      visit(child, Region.none);
    }

    return WordCounts(
      totalWords: totalWords,
      manuscriptWords: manuscriptWords,
      researchWords: researchWords,
      trashWords: trashWords,
    );
  }
}
