import 'dart:convert';

import 'package:appflowy_editor_sync_plugin/dart/document_types.dart';

/// Utilities for converting between different data representations
/// Replicates the functionality of the Rust conversion.rs
class Conversion {
  /// Convert a document state to JSON
  static Map<String, dynamic> documentToJson(DocumentState docState) {
    final blocksJson = <String, dynamic>{};

    for (final entry in docState.blocks.entries) {
      final block = entry.value;
      blocksJson[entry.key] = _blockToJson(block);
    }

    final childrenJson = <String, dynamic>{};
    for (final entry in docState.childrenMap.entries) {
      childrenJson[entry.key] = entry.value;
    }

    return {
      'docId': docState.docId,
      'blocks': blocksJson,
      'childrenMap': childrenJson,
      'rootId': docState.rootId,
    };
  }

  /// Convert a block to JSON
  static Map<String, dynamic> _blockToJson(BlockDoc block) {
    final json = <String, dynamic>{
      'id': block.id,
      'type': block.ty,
      'attributes': block.attributes,
    };

    if (block.parentId != null) {
      json['parentId'] = block.parentId;
    }

    if (block.prevId != null) {
      json['prevId'] = block.prevId;
    }

    if (block.nextId != null) {
      json['nextId'] = block.nextId;
    }

    if (block.delta != null) {
      json['delta'] = jsonDecode(block.delta!);
    }

    return json;
  }

  /// Convert JSON to document state
  static DocumentState jsonToDocument(Map<String, dynamic> json) {
    final blocks = <String, BlockDoc>{};
    final blocksJson = json['blocks'] as Map<String, dynamic>;

    for (final entry in blocksJson.entries) {
      blocks[entry.key] = jsonToBlock(entry.value as Map<String, dynamic>);
    }

    final childrenMap = <String, List<String>>{};
    final childrenJson = json['childrenMap'] as Map<String, dynamic>;

    for (final entry in childrenJson.entries) {
      childrenMap[entry.key] = List<String>.from(entry.value as List);
    }

    return DocumentState(
      docId: json['docId'] as String,
      blocks: blocks,
      childrenMap: childrenMap,
      rootId: json['rootId'] as String,
    );
  }

  /// Convert JSON to block
  static BlockDoc jsonToBlock(Map<String, dynamic> json) {
    final attributes = <String, String>{};
    final attrsJson = json['attributes'] as Map<String, dynamic>? ?? {};

    for (final entry in attrsJson.entries) {
      attributes[entry.key] = entry.value.toString();
    }

    String? delta;
    if (json.containsKey('delta')) {
      delta = jsonEncode(json['delta']);
    }

    return BlockDoc(
      id: json['id'] as String,
      ty: json['type'] as String,
      attributes: attributes,
      delta: delta,
      parentId: json['parentId'] as String?,
      prevId: json['prevId'] as String?,
      nextId: json['nextId'] as String?,
      oldParentId: json['oldParentId'] as String?,
    );
  }

  /// Convert delta operations to JSON
  static List<Map<String, dynamic>> deltasToJson(String deltaString) {
    try {
      final decoded = jsonDecode(deltaString);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((item) => item as Map<String, dynamic>),
        );
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Convert JSON to delta string
  static String jsonToDeltas(List<Map<String, dynamic>> deltas) {
    return jsonEncode(deltas);
  }

  /// Merge attributes from multiple blocks
  static Map<String, String> mergeAttributes(
    List<Map<String, String>> attributesList,
  ) {
    final merged = <String, String>{};

    for (final attrs in attributesList) {
      merged.addAll(attrs);
    }

    return merged;
  }

  /// Deep copy a block
  static BlockDoc copyBlock(BlockDoc block) {
    return BlockDoc(
      id: block.id,
      ty: block.ty,
      attributes: Map<String, String>.from(block.attributes),
      delta: block.delta,
      parentId: block.parentId,
      prevId: block.prevId,
      nextId: block.nextId,
      oldParentId: block.oldParentId,
    );
  }

  /// Deep copy document state
  static DocumentState copyDocumentState(DocumentState state) {
    final blocks = <String, BlockDoc>{};
    for (final entry in state.blocks.entries) {
      blocks[entry.key] = copyBlock(entry.value);
    }

    final childrenMap = <String, List<String>>{};
    for (final entry in state.childrenMap.entries) {
      childrenMap[entry.key] = List<String>.from(entry.value);
    }

    return DocumentState(
      docId: state.docId,
      blocks: blocks,
      childrenMap: childrenMap,
      rootId: state.rootId,
    );
  }

  /// Serialize document state to string
  static String serializeDocumentState(DocumentState state) {
    return jsonEncode(documentToJson(state));
  }

  /// Deserialize document state from string
  static DocumentState deserializeDocumentState(String json) {
    return jsonToDocument(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Convert attributes map to JSON-compatible format
  static Map<String, dynamic> attributesToJson(Map<String, String> attributes) {
    return Map<String, dynamic>.from(attributes);
  }

  /// Convert JSON to attributes map
  static Map<String, String> jsonToAttributes(Map<String, dynamic> json) {
    final result = <String, String>{};
    for (final entry in json.entries) {
      result[entry.key] = entry.value.toString();
    }
    return result;
  }

  /// Validate block structure
  static bool isValidBlock(BlockDoc block) {
    if (block.id.isEmpty) return false;
    if (block.ty.isEmpty) return false;

    // Validate delta if present
    if (block.delta != null) {
      try {
        jsonDecode(block.delta!);
      } catch (e) {
        return false;
      }
    }

    return true;
  }

  /// Validate document state
  static bool isValidDocumentState(DocumentState state) {
    if (state.docId.isEmpty) return false;
    if (state.rootId.isEmpty) return false;

    // Validate all blocks
    for (final block in state.blocks.values) {
      if (!isValidBlock(block)) return false;
    }

    // Validate children map references
    for (final children in state.childrenMap.values) {
      for (final childId in children) {
        if (!state.blocks.containsKey(childId)) {
          return false;
        }
      }
    }

    return true;
  }
}
