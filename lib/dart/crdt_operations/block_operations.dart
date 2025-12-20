import 'dart:convert';

import 'package:crdt/map_crdt.dart';

import '../document_types.dart';
import 'delta_operations.dart';

/// Block operations using native CRDT
/// Replicates the functionality of the Rust block_ops.rs
class BlockOperations {
  static const String _id = 'id';
  static const String _type = 'type';
  static const String _parentId = 'parentId';
  static const String _prevId = 'prevId';
  static const String _nextId = 'nextId';
  static const String _attributes = 'attributes';
  static const String _text = 'text';
  static const String _delta = 'delta';
  static const String _defaultParent = 'default_parent';

  /// Insert a new block node
  static Future<void> insertNode(BlockActionDoc action, MapCrdt crdt) async {
    final blockId = action.block.id;
    final parentId = action.block.parentId ?? _defaultParent;

    final blockData = <String, dynamic>{
      _id: blockId,
      _type: action.block.ty,
      _attributes: Map<String, String>.from(action.block.attributes),
    };

    if (parentId != _defaultParent) {
      blockData[_parentId] = parentId;
    }

    // Apply delta if present
    if (action.block.delta != null) {
      blockData[_delta] = action.block.delta;
      blockData[_text] = await DeltaOperations.applyDeltaToText(
        '',
        action.block.delta!,
      );
    }

    // Handle prev_id chain
    await _handlePrevIdChain(blockId, action.block.prevId, crdt);

    await _handleFollowingConnection(
      blockId,
      action.block.nextId,
      action.block.prevId,
      crdt,
    );

    // Set the prev_id for this block
    if (action.block.prevId != null) {
      blockData[_prevId] = action.block.prevId;
    }

    // Store block as JSON string in CRDT
    await crdt.put('blocks', blockId, jsonEncode(blockData));
  }

  /// Update an existing block node
  static Future<void> updateNode(BlockActionDoc action, MapCrdt crdt) async {
    final blockId = action.block.id;
    final blockDataJson = crdt.get('blocks', blockId) as String?;

    if (blockDataJson == null) {
      throw Exception('Block $blockId not found');
    }

    final blockData = jsonDecode(blockDataJson) as Map<String, dynamic>;

    // Update attributes if any
    if (action.block.attributes.isNotEmpty) {
      final attributes = blockData[_attributes] as Map<String, dynamic>? ?? {};
      attributes.addAll(action.block.attributes);
      blockData[_attributes] = attributes;
    }

    // Apply delta if present
    if (action.block.delta != null) {
      final currentText = blockData[_text] as String? ?? '';
      blockData[_text] = await DeltaOperations.applyDeltaToText(
        currentText,
        action.block.delta!,
      );
      blockData[_delta] = action.block.delta;
    }

    // Store updated block
    await crdt.put('blocks', blockId, jsonEncode(blockData));
  }

  /// Delete a block node and its descendants
  static Future<void> deleteNode(
    String blockId,
    String parentId,
    MapCrdt crdt,
  ) async {
    // Build parent-child structure
    final blocksByParent = _buildParentChildStructure(crdt);

    // Get all descendants
    final descendants = _findDescendants(blockId, blocksByParent);

    // Update the prev_id chain for the main block
    await _removeBlockFromPrevIdChain(blockId, crdt);

    // Delete all descendants from bottom up
    for (final descendantId in descendants) {
      await _removeBlockFromPrevIdChain(descendantId, crdt);
      // Use put with isDeleted=true instead of delete
      await crdt.put('blocks', descendantId, '', true);
    }

    // Finally remove the main block
    await crdt.put('blocks', blockId, '', true);
  }

  /// Move a block to a new parent
  static Future<void> moveBlock(
    List<int> oldPath,
    List<int> newPath,
    String parentId,
    String oldParentId,
    String blockId,
    String? prevId,
    String? nextId,
    MapCrdt crdt,
  ) async {
    // Update the prev_id chain
    await _removeBlockFromPrevIdChain(blockId, crdt);

    await _handleFollowingConnection(blockId, nextId, prevId, crdt);

    final blockDataJson = crdt.get('blocks', blockId) as String?;
    if (blockDataJson == null) {
      throw Exception('Block $blockId not found');
    }

    final blockData = jsonDecode(blockDataJson) as Map<String, dynamic>;

    // Set the new prev_id or remove it
    if (prevId != null) {
      blockData[_prevId] = prevId;
    } else {
      blockData.remove(_prevId);
    }

    // Save new parent id
    if (parentId != oldParentId) {
      if (parentId != _defaultParent) {
        blockData[_parentId] = parentId;
      } else {
        blockData.remove(_parentId);
      }
    }

    // Store updated block
    await crdt.put('blocks', blockId, jsonEncode(blockData));
  }

  // Private helper methods

  static List<String> _findBlockReferencingPrevId(
    String prevIdValue,
    MapCrdt crdt,
  ) {
    final results = <String>[];
    final blocksMap = crdt.getMap('blocks');

    for (final entry in blocksMap.entries) {
      try {
        final blockDataJson = entry.value as String;
        final blockData = jsonDecode(blockDataJson) as Map<String, dynamic>;
        final blockPrevId = blockData[_prevId] as String?;

        if (blockPrevId == prevIdValue) {
          results.add(entry.key);
        }
      } catch (e) {
        // Skip malformed blocks
        continue;
      }
    }

    return results;
  }

  static Future<void> _handlePrevIdChain(
    String blockId,
    String? prevId,
    MapCrdt crdt,
  ) async {
    if (prevId == null) return;

    // Find all blocks that have this prev_id
    final blocksWithSamePrevId = _findBlockReferencingPrevId(prevId, crdt);

    // Update each block that references this prev_id to now point to this block
    for (final otherBlockId in blocksWithSamePrevId) {
      final otherBlockJson = crdt.get('blocks', otherBlockId) as String?;
      if (otherBlockJson == null) continue;

      final otherBlock = jsonDecode(otherBlockJson) as Map<String, dynamic>;
      otherBlock[_prevId] = blockId;
      await crdt.put('blocks', otherBlockId, jsonEncode(otherBlock));
    }
  }

  static Future<void> _removeBlockFromPrevIdChain(
    String blockId,
    MapCrdt crdt,
  ) async {
    final blockDataJson = crdt.get('blocks', blockId) as String?;
    if (blockDataJson == null) return;

    try {
      final blockData = jsonDecode(blockDataJson) as Map<String, dynamic>;
      final prevId = blockData[_prevId] as String?;

      // Find all blocks that reference this block as their prev_id
      final nextBlocks = _findBlockReferencingPrevId(blockId, crdt);

      // Update each next block to point to this block's prev_id
      for (final nextId in nextBlocks) {
        final nextBlockJson = crdt.get('blocks', nextId) as String?;
        if (nextBlockJson == null) continue;

        final nextBlock = jsonDecode(nextBlockJson) as Map<String, dynamic>;

        if (prevId != null) {
          nextBlock[_prevId] = prevId;
        } else {
          nextBlock.remove(_prevId);

          // Copy device and timestamp attributes
          final attributes =
              nextBlock[_attributes] as Map<String, dynamic>? ?? {};
          final blockAttrs =
              blockData[_attributes] as Map<String, dynamic>? ?? {};

          if (blockAttrs.containsKey('device')) {
            attributes['device'] = blockAttrs['device'];
          }
          if (blockAttrs.containsKey('timestamp')) {
            attributes['timestamp'] = blockAttrs['timestamp'];
          }

          nextBlock[_attributes] = attributes;
        }

        await crdt.put('blocks', nextId, jsonEncode(nextBlock));
      }
    } catch (e) {
      // Skip if block data is malformed
    }
  }

  static Future<void> _handleFollowingConnection(
    String blockId,
    String? nextId,
    String? prevId,
    MapCrdt crdt,
  ) async {
    // If there is prev_id, use prev_id strategy
    if (prevId != null) {
      final nextNodes = _findBlockReferencingPrevId(prevId, crdt);

      for (final nextNodeId in nextNodes) {
        final nextBlockJson = crdt.get('blocks', nextNodeId) as String?;
        if (nextBlockJson == null) continue;

        final nextBlock = jsonDecode(nextBlockJson) as Map<String, dynamic>;
        nextBlock[_prevId] = blockId;
        await crdt.put('blocks', nextNodeId, jsonEncode(nextBlock));
      }
    }

    // If there is next_id, use it as well
    if (nextId != null) {
      final nextBlockJson = crdt.get('blocks', nextId) as String?;
      if (nextBlockJson != null) {
        try {
          final nextBlock = jsonDecode(nextBlockJson) as Map<String, dynamic>;
          nextBlock[_prevId] = blockId;

          // Copy device and timestamp attributes
          final blockJson = crdt.get('blocks', blockId) as String?;
          if (blockJson != null) {
            final block = jsonDecode(blockJson) as Map<String, dynamic>;
            final attributes =
                block[_attributes] as Map<String, dynamic>? ?? {};
            final nextAttrs =
                nextBlock[_attributes] as Map<String, dynamic>? ?? {};

            if (nextAttrs.containsKey('device')) {
              attributes['device'] = nextAttrs['device'];
            }
            if (nextAttrs.containsKey('timestamp')) {
              attributes['timestamp'] = nextAttrs['timestamp'];
            }

            block[_attributes] = attributes;
            await crdt.put('blocks', blockId, jsonEncode(block));
          }

          await crdt.put('blocks', nextId, jsonEncode(nextBlock));
        } catch (e) {
          // Skip if block data is malformed
        }
      }
    }
  }

  static Map<String, List<String>> _buildParentChildStructure(MapCrdt crdt) {
    final blocksByParent = <String, List<String>>{};
    final blocksMap = crdt.getMap('blocks');

    for (final entry in blocksMap.entries) {
      try {
        final blockId = entry.key;
        final blockDataJson = entry.value as String;
        final blockData = jsonDecode(blockDataJson) as Map<String, dynamic>;
        final parentId = blockData[_parentId] as String? ?? 'root';

        blocksByParent.putIfAbsent(parentId, () => []).add(blockId);
      } catch (e) {
        // Skip malformed blocks
        continue;
      }
    }

    return blocksByParent;
  }

  static List<String> _findDescendants(
    String blockId,
    Map<String, List<String>> blocksByParent,
  ) {
    final descendants = <String>[];

    // Get direct children
    final children = blocksByParent[blockId];
    if (children != null) {
      for (final childId in children) {
        descendants.add(childId);

        // Recursively get children of children
        final childDescendants = _findDescendants(childId, blocksByParent);
        descendants.addAll(childDescendants);
      }
    }

    return descendants;
  }
}
