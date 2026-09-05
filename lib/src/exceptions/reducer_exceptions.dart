/// Thrown when an operation targets a node that does not exist in the tree.
class NodeNotFoundException implements Exception {
  const NodeNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'NodeNotFoundException: no node with id "$id".';
}

/// Thrown when a node cannot be created / moved to the requested parent.
class InvalidParentException implements Exception {
  const InvalidParentException(this.id, this.reason);

  final String id;
  final String reason;

  @override
  String toString() => 'InvalidParentException: parent "$id" $reason.';
}

/// Thrown when a move would create a cycle or is otherwise not allowed.
class InvalidMoveException implements Exception {
  const InvalidMoveException(this.nodeId, this.targetId);

  final String nodeId;
  final String targetId;

  @override
  String toString() =>
      'InvalidMoveException: cannot move "$nodeId" into "$targetId".';
}

/// Thrown when an operation cannot be applied to the resolved node type.
class NodeTypeException implements Exception {
  const NodeTypeException(this.id, this.expected);

  final String id;
  final String expected;

  @override
  String toString() => 'NodeTypeException: node "$id" is not $expected.';
}
