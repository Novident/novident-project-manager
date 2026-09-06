import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_nodes/novident_nodes.dart';

import '../exceptions/reducer_exceptions.dart';

/// Binder tree operations (the tree lives in a `Folder` root).
///
/// Reading node state goes through the mixin interfaces ([UniversalName],
/// [AttachableSection], [Trashable]) so no code depends on the concrete node
/// type. Only creation needs the concrete constructors ([Document] vs
/// [Folder]).
///
/// Every mutation goes through the [NodeContainer] API (`add`, `updateAt`,
/// `removeAt`, `moveTo`) — never by poking `children` directly — so level
/// re-assignment, ownership and change notifications stay consistent. All
/// methods mutate the passed [root] in place and let the container fire the
/// corresponding [NodeChange] (insertion / update / move / deletion).
class BinderActions {
  const BinderActions._();

  /// Resolves a node by id, or returns `null`.
  static Node? findNode(Folder root, String id) {
    if (root.id == id) return root;
    return root.visitAllNodes(shouldGetNode: (Node node) => node.id == id);
  }

  /// Resolves a node by id, or throws [NodeNotFoundException].
  static Node requireNode(Folder root, String id) {
    final Node? node = findNode(root, id);
    if (node == null) throw NodeNotFoundException(id);
    return node;
  }

  /// Resolves the special Trash folder of the project.
  static Folder? findTrashFolder(Folder root) {
    final Node? node = root.visitAllNodes(
      shouldGetNode: (Node n) => n is Folder && n.type.isTrashFolder,
    );
    return node is Folder ? node : null;
  }

  /// Resolves a folder by id, or throws.
  static Folder requireFolder(Folder root, String id) {
    final Node node = requireNode(root, id);
    if (node is! Folder) throw NodeTypeException(id, 'folder');
    return node;
  }

  /// Display name of a node, through [UniversalName].
  static String nameOf(Node node) {
    if (node is! UniversalName) {
      throw NodeTypeException(node.id, 'a named node');
    }
    return (node as UniversalName).objectName;
  }

  /// Attached section of a node, through [AttachableSection].
  static String sectionOf(Node node) {
    if (node is! AttachableSection) {
      return NovidentDefaults.kStructuredBasedSectionId;
    }
    return (node as AttachableSection).section;
  }

  /// Whether the node is currently trashed, through [Trashable].
  static bool isTrashed(Node node) {
    if (node is! Trashable) return false;
    return (node as Trashable).trashStatus.isTrashed;
  }

  /// Creates and inserts a [Document] into [parentId].
  static Document createDocument(
    Folder root, {
    required String parentId,
    required String name,
    String? id,
    String? section,
    int level = 0,
  }) {
    final Folder parent = _writableFolder(root, parentId);
    final Document document = Document(
      details:
          NodeDetails.byId(level: level, id: id ?? NodeDetails.createNodeId()),
      name: name,
      attachedSection: section ?? NovidentDefaults.kStructuredBasedSectionId,
    );
    parent.add(document);
    return document;
  }

  /// Creates and inserts a [Folder] into [parentId].
  static Folder createFolder(
    Folder root, {
    required String parentId,
    required String name,
    String? id,
    String? section,
    FolderType folderType = FolderType.normal,
  }) {
    final Folder parent = _writableFolder(root, parentId);
    final Folder folder = Folder(
      children: <Node>[],
      details: NodeDetails.byId(level: 0, id: id ?? NodeDetails.createNodeId()),
      name: name,
      attachedSection: section ?? NovidentDefaults.kStructuredBasedSectionId,
      folderType: folderType,
    );
    parent.add(folder);
    return folder;
  }

  /// Parent must exist, be a folder, and not be trashed.
  static Folder _writableFolder(Folder root, String parentId) {
    final Folder parent = requireFolder(root, parentId);
    if (isTrashed(parent) || parent.type.isTrashFolder) {
      throw InvalidParentException(parentId, 'is not writable');
    }
    return parent;
  }

  /// Renames a node by updating it in place with a new copy.
  static Node renameNode(Folder root, String id, String newName) {
    final Node node = requireNode(root, id);
    if (node is! UniversalName) throw NodeTypeException(id, 'a named node');
    final Node replacement = switch (node) {
      Folder folder => folder.copyWith(name: newName),
      Document document => document.copyWith(name: newName),
      DocumentResource document => document.copyWith(name: newName),
      _ => throw NodeTypeException(id, 'document or folder'),
    };
    _replaceInParent(node, replacement);
    return replacement;
  }

  /// Sets the attached section of a node.
  static Node setNodeSection(Folder root, String id, String section) {
    final Node node = requireNode(root, id);
    if (node is! AttachableSection) {
      throw NodeTypeException(id, 'a section-attachable node');
    }
    final Node replacement = switch (node) {
      Folder folder => folder.copyWith(attachedSection: section),
      Document document => document.copyWith(attachedSection: section),
      _ => throw NodeTypeException(id, 'document or folder'),
    };
    _replaceInParent(node, replacement);
    return replacement;
  }

  /// Updates [node] with [replacement] through the container's [NodeContainer.updateAt]
  /// so ownership, levels and the [NodeUpdate] change event stay consistent.
  static void _replaceInParent(Node node, Node replacement) {
    final NodeContainer? owner = node.owner;
    if (owner == null) {
      throw InvalidParentException(node.id, 'has no owner to replace it in');
    }
    owner.updateAt(
      node.index,
      replacement,
      shouldNotify: true,
      propagateNotifications: true,
    );
  }

  /// Moves a node into [targetFolderId] (append, or at [index]).
  ///
  /// The cycle guard lives in [Node.canMoveTo]. Moving into the Trash folder is
  /// only reachable through [trashNode], so a plain move rejects it.
  static void moveNode(
    Folder root, {
    required String nodeId,
    required String targetFolderId,
    int? index,
  }) {
    final Node node = requireNode(root, nodeId);
    final Folder target = requireFolder(root, targetFolderId);
    if (target.type.isTrashFolder) {
      throw InvalidMoveException(nodeId, targetFolderId);
    }
    _moveChecked(node, target, index: index);
  }

  /// Moves a node into the Trash folder.
  ///
  /// The trashing feature is applied while the node still has an owner:
  /// `Folder.setTrashState` refuses to act on an owner-less folder, and
  /// `Node.moveTo` unlinks *before* inserting, so the auto-trash on insertion
  /// would be a no-op for folders. The trashed copy replaces the original in
  /// place and is then moved into the Trash folder.
  static void trashNode(Folder root, String id) {
    final Node node = requireNode(root, id);
    if (node.owner == null) {
      throw InvalidParentException(id, 'is the project root');
    }
    if (node is Folder && node.type.isNotNormalFolder) {
      throw InvalidParentException(id, 'is a special folder');
    }
    if (node is! Trashable) {
      throw NodeTypeException(id, 'a trashable node');
    }
    final Folder? trash = findTrashFolder(root);
    if (trash == null) {
      throw InvalidParentException(id, 'project has no Trash folder');
    }
    if (isTrashed(node)) return;

    // Apply the trash state (recursively for folders) while owner is set.
    final Node trashed = (node as Trashable).setTrashState();
    _replaceInParent(node, trashed);
    _moveChecked(requireNode(root, id), trash);
  }

  /// Restores a trashed node by moving it out of the trash (the target folder
  /// auto-clears the trashing feature on insertion).
  static void restoreNode(
    Folder root, {
    required String id,
    required String targetFolderId,
    int? index,
  }) {
    final Node node = requireNode(root, id);
    if (!isTrashed(node)) {
      throw InvalidParentException(id, 'is not trashed');
    }
    final Folder target = requireFolder(root, targetFolderId);
    if (target.type.isTrashFolder) {
      throw InvalidMoveException(id, targetFolderId);
    }
    _moveChecked(node, target, index: index);
  }

  /// Move with the cycle/ancestor guard from [Node.canMoveTo].
  static void _moveChecked(Node node, Folder target, {int? index}) {
    if (!Node.canMoveTo(node: node, target: target, inside: true)) {
      throw InvalidMoveException(node.id, target.id);
    }
    Node.moveTo(node: node, newOwner: target, index: index);
  }

  /// Removes a node from the tree permanently and returns the ids of the
  /// document directories (`files/<id>/`) the node owned that must be deleted
  /// on disk: its own, for a document; every descendant document, for a folder.
  static List<String> purgeNode(Folder root, String id) {
    final Node node = requireNode(root, id);
    final NodeContainer? owner = node.owner;
    if (owner == null) {
      throw InvalidParentException(id, 'is the root and cannot be purged');
    }

    final List<String> fileIds = <String>[];
    if (node is Folder) {
      node.visitAllNodes(
        shouldGetNode: (Node candidate) {
          if (candidate is Document) fileIds.add(candidate.id);
          return false;
        },
      );
    } else if (node is Document) {
      fileIds.add(node.id);
    }

    owner.removeAt(
      node.index,
      shouldNotify: true,
      propagateNotifications: true,
    );
    return fileIds;
  }
}
