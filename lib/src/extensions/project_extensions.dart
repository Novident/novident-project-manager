import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_nodes/novident_nodes.dart';

import '../../novident_project_manager.dart';

extension SpecialSourcesSearchExtension on ProjectManager {
  List<DocumentResource> getResources({bool onlyUseResearch = true}) {
    if (!binder.isLoaded) {
      return [];
    }
    final List<DocumentResource> resources = <DocumentResource>[];
    if (onlyUseResearch) {
      final Folder? research = binder.root
          .visitAllNodes(
            shouldGetNode: (node) =>
                node is Folder && node.type.isResearchFolder,
          )
          .cast<Folder?>();
      if (research != null) {
        return resources
          ..addAll(research
              .whereDeep((node) => node is DocumentResource && node.isResource)
              .cast<DocumentResource>());
      }
    }
    return resources
      ..addAll(binder.root
          .whereDeep(
            (Node node) => node is DocumentResource && node.isResource,
          )
          .cast<DocumentResource>());
  }

  /// Return TemplatesSheet folder
  Folder? getTemplateSheet() {
    if (!binder.isLoaded) {
      return null;
    }

    return binder.root.visitAllNodes(shouldGetNode: (Node node) {
      if (node is! Folder) {
        return false;
      }
      return node.type.isTemplatesSheetFolder;
    }).cast<Folder?>();
  }

  /// Return all the nodes into the TemplatesSheet folder
  ///
  List<Node> getTemplates() {
    return <Node>[
      ...?getTemplateSheet()?.children,
    ];
  }
}
