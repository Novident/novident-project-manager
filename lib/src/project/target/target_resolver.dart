// ignore_for_file: non_constant_identifier_names

import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_project_manager/src/project/target/target.dart';

/// The writing target that applies to one node.
///
/// A node either carries its own override (`target.index.json` → `files`) or
/// inherits the project-wide `general` target. [isOverride] tells which one.
class NodeTarget {
  const NodeTarget({
    required this.nodeId,
    required this.words,
    required this.characters,
    required this.isOverride,
    this.typeTarget,
    this.deadline,
    this.notify = false,
    this.charactersNoSpaces,
  });

  final String nodeId;

  /// Target words for the node.
  final int words;

  /// Target characters for the node.
  final int characters;

  /// Whether [words]/[characters] come from a per-node override.
  final bool isOverride;

  /// Goal type (`nanowrimo`, …) — only meaningful from the `general` block.
  final String? typeTarget;

  final String? deadline;
  final bool notify;

  /// Per-node no-spaces character target, when the override carries one.
  final int? charactersNoSpaces;
}

/// Resolves the effective writing target of any node.
///
/// Queries run over the loaded [TargetIndex] plus the binder [root]:
/// - a node with an entry in `index.files` uses **its own** target;
/// - any other node inherits the **general** target;
/// - a folder query returns every descendant node (and the folder itself) that
///   has its own configured override — nodes without one already fall back to
///   the general target, so repeating it per child adds no information.
class TargetResolver {
  TargetResolver({required this.index, required this.root});

  final TargetIndex index;
  final Folder root;

  /// Resolves the effective target of [nodeId], or `null` when the node does
  /// not exist in the binder.
  NodeTarget? targetOf(String nodeId) {
    final Node? node = _findNode(nodeId);
    if (node == null) return null;

    final TargetFile? override = index.files[nodeId];
    if (override != null) {
      return NodeTarget(
        nodeId: nodeId,
        words: override.words,
        characters: override.characters,
        deadline: override.deadline,
        notify: override.notify,
        isOverride: true,
      );
    }
    return _inherited(nodeId);
  }

  /// Every node inside [folderId] (folder itself included) that has its own
  /// configured target override. Empty when the folder has none.
  List<NodeTarget> targetsWithinFolder(String folderId) {
    final Node? folderNode = _findNode(folderId);
    if (folderNode is! Folder) return const <NodeTarget>[];

    final List<NodeTarget> targets = <NodeTarget>[];
    if (index.files.containsKey(folderId)) {
      targets.add(_overrideFor(folderId));
    }
    folderNode.visitAllNodes(shouldGetNode: (Node node) {
      if (node.id != folderId && index.files.containsKey(node.id)) {
        targets.add(_overrideFor(node.id));
      }
      return false;
    });
    return targets;
  }

  NodeTarget _inherited(String nodeId) {
    return NodeTarget(
      nodeId: nodeId,
      words: index.general.target,
      characters: index.general.targetCharacters,
      typeTarget: index.general.typeTarget,
      deadline: index.general.deadline,
      isOverride: false,
    );
  }

  NodeTarget _overrideFor(String nodeId) {
    final TargetFile override = index.files[nodeId]!;
    return NodeTarget(
      nodeId: nodeId,
      words: override.words,
      characters: override.characters,
      deadline: override.deadline,
      notify: override.notify,
      isOverride: true,
    );
  }

  Node? _findNode(String id) {
    if (root.id == id) return root;
    return root.visitAllNodes(shouldGetNode: (Node node) => node.id == id);
  }
}
