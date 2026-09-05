import 'dart:convert';

import '../../schema/registry.dart';

/// Corkboard visual state (`indexation/corkboard.index.json`).
class CorkboardIndex {
  final int? schemaVersion;
  final List<Corkboard> corkboards;

  const CorkboardIndex({
    this.schemaVersion = kCurrentSchemaVersion,
    this.corkboards = const <Corkboard>[],
  });

  factory CorkboardIndex.fromJson(Map<String, dynamic> json) {
    final rawCorkboards = json['corkboards'];
    return CorkboardIndex(
      schemaVersion: json['schema_version'] as int?,
      corkboards: rawCorkboards is List
          ? rawCorkboards
              .map((dynamic e) => Corkboard.fromJson(e as Map<String, dynamic>))
              .toList()
          : const <Corkboard>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (schemaVersion != null) 'schema_version': schemaVersion,
        'corkboards': corkboards
            .map(
              (Corkboard corkboard) => corkboard.toJson(),
            )
            .toList(),
      };

  String toJsonString() => json.encode(toJson());

  factory CorkboardIndex.fromJsonString(String source) =>
      CorkboardIndex.fromJson(json.decode(source) as Map<String, dynamic>);
}

/// Visual state persisted for one binder element shown on a corkboard.
class Corkboard {
  final String elementId;
  final String elementName;
  final String elementPath;
  final CorkboardValues values;

  const Corkboard({
    this.elementId = '',
    this.elementName = '',
    this.elementPath = '',
    this.values = const CorkboardValues(),
  });

  factory Corkboard.fromJson(Map<String, dynamic> json) => Corkboard(
        elementId: json['element_id'] as String? ?? '',
        elementName: json['element_name'] as String? ?? '',
        elementPath: json['element_path'] as String? ?? '',
        values: CorkboardValues.fromJson(
            json['values'] as Map<String, dynamic>? ?? const {}),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'element_id': elementId,
        'element_name': elementName,
        'element_path': elementPath,
        'values': values.toJson(),
      };
}

class CorkboardValues {
  /// Null when the element has no free-form board of its own.
  final Freeform? freeform;
  final double ratio;
  final double spacing;

  const CorkboardValues({
    this.freeform,
    this.ratio = 0,
    this.spacing = 0,
  });

  factory CorkboardValues.fromJson(Map<String, dynamic> json) {
    final rawFreeform = json['freeform'];
    return CorkboardValues(
      freeform: rawFreeform is Map<String, dynamic>
          ? Freeform.fromJson(rawFreeform)
          : null,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
      spacing: (json['spacing'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'freeform': freeform?.toJson(),
        'ratio': ratio,
        'spacing': spacing,
      };
}

class Freeform {
  final FreeformWorld world;
  final FreeformViewport viewport;
  final List<String> zIndex;
  final String? selectedNodeId;
  final String? config;

  const Freeform({
    this.world = const FreeformWorld(),
    this.viewport = const FreeformViewport(),
    this.zIndex = const <String>[],
    this.selectedNodeId,
    this.config,
  });

  factory Freeform.fromJson(Map<String, dynamic> json) => Freeform(
        world: FreeformWorld.fromJson(
            json['world'] as Map<String, dynamic>? ?? const {}),
        viewport: FreeformViewport.fromJson(
            json['viewport'] as Map<String, dynamic>? ?? const {}),
        zIndex: (json['z_index'] as List?)?.cast<String>() ?? const <String>[],
        selectedNodeId: json['selected_node_id'] as String?,
        config: json['config'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'world': world.toJson(),
        'viewport': viewport.toJson(),
        'z_index': zIndex,
        if (selectedNodeId != null) 'selected_node_id': selectedNodeId,
        if (config != null) 'config': config,
      };
}

class FreeformWorld {
  final List<WorldNode> nodes;

  const FreeformWorld({this.nodes = const <WorldNode>[]});

  factory FreeformWorld.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'];
    return FreeformWorld(
      nodes: rawNodes is List
          ? rawNodes
              .map((dynamic e) => WorldNode.fromJson(e as Map<String, dynamic>))
              .toList()
          : const <WorldNode>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'nodes': nodes.map((WorldNode n) => n.toJson()).toList()
      };
}

class WorldNode {
  final String nodeId;
  final String nodeName;
  final double x;
  final double y;
  final double width;
  final double height;

  const WorldNode({
    this.nodeId = '',
    this.nodeName = '',
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
  });

  factory WorldNode.fromJson(Map<String, dynamic> json) => WorldNode(
        nodeId: json['node_id'] as String? ?? '',
        nodeName: json['node_name'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'node_id': nodeId,
        'node_name': nodeName,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

class FreeformViewport {
  final double offsetX;
  final double offsetY;

  const FreeformViewport({this.offsetX = 0, this.offsetY = 0});

  factory FreeformViewport.fromJson(Map<String, dynamic> json) =>
      FreeformViewport(
        offsetX: (json['offset_x'] as num?)?.toDouble() ?? 0,
        offsetY: (json['offset_y'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'offset_x': offsetX,
        'offset_y': offsetY,
      };
}
