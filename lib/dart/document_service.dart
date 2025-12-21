import 'dart:convert';

import 'package:appflowy_editor_sync_plugin/dart/crdt_operations/conversion.dart';
import 'package:crdt/map_crdt.dart';
import 'package:flutter/foundation.dart';

import 'crdt_operations/block_operations.dart';
import 'crdt_operations/update_operations.dart';
import 'document_types.dart';

/// Native Dart implementation of DocumentService using the crdt package
/// Maintains the same API as the Rust version for drop-in replacement
class DocumentService {
  late MapCrdt _crdt;
  final String _docId;
  final String _nodeId;

  DocumentService({String? nodeId})
    : _docId = "xxxx",
      _nodeId = nodeId ?? _generateNodeId() {
    _crdt = MapCrdt(['document', 'blocks']);
  }

  /// Generate a unique node ID for this CRDT instance
  static String _generateNodeId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 1000}';
  }

  /// Initialize an empty document
  Future<Uint8List> initEmptyDoc() async {
    // Initialize the document structure with root
    await _crdt.put('document', 'root', 'root');

    // Return the initial changeset as binary data
    final changeset = _crdt.getChangeset();
    return UpdateOperations.encodeChangeset(changeset);
  }

  /// Apply block actions (insert, update, delete, move)
  Future<Uint8List> applyAction({required List<BlockActionDoc> actions}) async {
    final beforeChangeset = _crdt.getChangeset();

    for (final action in actions) {
      await _applyBlockAction(action);
    }

    // Get the diff between before and after
    final afterChangeset = _crdt.getChangeset();
    final diff = UpdateOperations.computeChangesetDiff(
      beforeChangeset,
      afterChangeset,
    );

    return UpdateOperations.encodeChangeset(diff);
  }

  /// Apply updates from remote peers
  Future<void> applyUpdates({required List<Uint8List> updates}) async {
    for (final update in updates) {
      final changeset = UpdateOperations.decodeChangeset(update);
      debugPrint('Applying changeset: $changeset');
      await _crdt.merge(changeset);
    }
  }

  /// Get the current document state
  Future<DocumentState> getDocumentState() async {
    final blocks = <String, BlockDoc>{};

    // Extract blocks from CRDT
    final blocksMap = _crdt.getMap('blocks');

    for (final entry in blocksMap.entries) {
      final blockId = entry.key;
      final blockDataJson = entry.value as String;

      try {
        final blockData = jsonDecode(blockDataJson) as Map<String, dynamic>;
        blocks[blockId] = Conversion.jsonToBlock(blockData);
      } catch (e) {
        // Skip malformed blocks
        continue;
      }
    }

    // Build children map by analyzing parent-child relationships
    final sortedChildren = _buildChildrenMap(blocks);

    final rootId = _crdt.get('document', 'root') as String? ?? 'root';
    debugPrint('Blocks: $blocks');
    return DocumentState(
      docId: _docId,
      blocks: blocks,
      childrenMap: sortedChildren,
      rootId: rootId,
    );
  }

  /// Merge multiple updates into one
  Future<Uint8List> mergeUpdates({required List<Uint8List> updates}) async {
    if (updates.isEmpty) {
      return Uint8List(0);
    }

    // Decode all changesets
    final changesets =
        updates.map((u) => UpdateOperations.decodeChangeset(u)).toList();

    // Merge them
    final merged = UpdateOperations.mergeChangesets(changesets);

    return UpdateOperations.encodeChangeset(merged);
  }

  /// Set the root node ID
  Future<Uint8List> setRootNodeId({required String id}) async {
    final beforeChangeset = _crdt.getChangeset();

    await _crdt.put('document', 'root', id);

    final afterChangeset = _crdt.getChangeset();
    final diff = UpdateOperations.computeChangesetDiff(
      beforeChangeset,
      afterChangeset,
    );

    return UpdateOperations.encodeChangeset(diff);
  }

  // Private helper methods

  Future<void> _applyBlockAction(BlockActionDoc action) async {
    switch (action.action) {
      case BlockActionTypeDoc.insert:
        await BlockOperations.insertNode(action, _crdt);
        break;

      case BlockActionTypeDoc.update:
        await BlockOperations.updateNode(action, _crdt);
        break;

      case BlockActionTypeDoc.delete:
        final parentId = action.block.parentId ?? 'default_parent';
        await BlockOperations.deleteNode(action.block.id, parentId, _crdt);
        break;

      case BlockActionTypeDoc.move:
        if (action.oldPath != null &&
            action.block.parentId != null &&
            action.block.oldParentId != null) {
          await BlockOperations.moveBlock(
            action.oldPath!,
            action.path,
            action.block.parentId!,
            action.block.oldParentId!,
            action.block.id,
            action.block.prevId,
            action.block.nextId,
            _crdt,
          );
        } else {
          throw Exception('Missing required fields for move operation');
        }
        break;
    }
  }

  Map<String, List<String>> _buildChildrenMap(Map<String, BlockDoc> blocks) {
    final childrenMap = <String, List<String>>{};

    // First pass: build parent-child relationships
    for (final block in blocks.values) {
      final parentId = block.parentId ?? 'root';
      childrenMap.putIfAbsent(parentId, () => []).add(block.id);
    }

    // Second pass: sort children by prevId chain
    for (final entry in childrenMap.entries) {
      final parentId = entry.key;
      final children = entry.value;

      if (children.length > 1) {
        childrenMap[parentId] = _sortByPrevIdChain(children, blocks);
      }
    }

    return childrenMap;
  }

  List<String> _sortByPrevIdChain(
    List<String> blockIds,
    Map<String, BlockDoc> blocks,
  ) {
    // Build a map of prevId -> blockId
    final prevIdMap = <String?, String>{};
    final blockSet = blockIds.toSet();

    for (final id in blockIds) {
      final block = blocks[id];
      if (block != null) {
        prevIdMap[block.prevId] = id;
      }
    }

    // Find the first block (one with no prevId or prevId not in this set)
    String? firstId;
    for (final id in blockIds) {
      final block = blocks[id];
      if (block?.prevId == null || !blockSet.contains(block?.prevId)) {
        firstId = id;
        break;
      }
    }

    if (firstId == null) return blockIds;

    // Build the sorted list by following the chain
    final sorted = <String>[firstId];
    var current = firstId;

    while (sorted.length < blockIds.length) {
      final next = prevIdMap[current];
      if (next == null) break;
      sorted.add(next);
      current = next;
    }

    // Add any remaining blocks that weren't in the chain
    for (final id in blockIds) {
      if (!sorted.contains(id)) {
        sorted.add(id);
      }
    }

    return sorted;
  }

  /// Factory constructor to maintain compatibility with flutter_rust_bridge
  static Future<DocumentService> newInstance() async {
    return DocumentService();
  }
}
