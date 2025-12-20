import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'document_types.freezed.dart';
part 'document_types.g.dart';

/// Block action types for document operations
enum BlockActionTypeDoc {
  @JsonValue('insert')
  insert,
  @JsonValue('update')
  update,
  @JsonValue('delete')
  delete,
  @JsonValue('move')
  move,
}

/// Represents a block in the document
@freezed
sealed class BlockDoc with _$BlockDoc {
  const factory BlockDoc({
    required String id,
    required String ty,
    required Map<String, String> attributes,
    String? delta,
    String? parentId,
    String? prevId,
    String? nextId,
    String? oldParentId,
  }) = _BlockDoc;

  factory BlockDoc.fromJson(Map<String, dynamic> json) =>
      _$BlockDocFromJson(json);
}

/// Represents an action to be performed on a block
@freezed
sealed class BlockActionDoc with _$BlockActionDoc {
  const factory BlockActionDoc({
    required BlockActionTypeDoc action,
    required BlockDoc block,
    @Uint32ListConverter() required Uint32List path,
    @Uint32ListConverter() Uint32List? oldPath,
  }) = _BlockActionDoc;

  factory BlockActionDoc.fromJson(Map<String, dynamic> json) =>
      _$BlockActionDocFromJson(json);
}

/// Represents the complete document state
@freezed
sealed class DocumentState with _$DocumentState {
  const factory DocumentState({
    required String docId,
    required Map<String, BlockDoc> blocks,
    required Map<String, List<String>> childrenMap,
    required String rootId,
  }) = _DocumentState;

  factory DocumentState.fromJson(Map<String, dynamic> json) =>
      _$DocumentStateFromJson(json);
}

/// Represents failed update decoding information
@freezed
sealed class FailedToDecodeUpdates with _$FailedToDecodeUpdates {
  const factory FailedToDecodeUpdates({
    required List<String> failedUpdatesIds,
  }) = _FailedToDecodeUpdates;

  factory FailedToDecodeUpdates.fromJson(Map<String, dynamic> json) =>
      _$FailedToDecodeUpdatesFromJson(json);
}

/// Custom error type for document operations
class CustomRustError implements Exception {
  final String message;

  const CustomRustError({required this.message});

  /// Create a new error instance
  factory CustomRustError.newInstance({required String message}) {
    return CustomRustError(message: message);
  }

  @override
  String toString() => 'CustomRustError: $message';

  @override
  int get hashCode => message.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomRustError &&
          runtimeType == other.runtimeType &&
          message == other.message;
}

/// Converter for Uint32List to work with JSON serialization
class Uint32ListConverter implements JsonConverter<Uint32List, List<dynamic>> {
  const Uint32ListConverter();

  @override
  Uint32List fromJson(List<dynamic> json) {
    return Uint32List.fromList(json.cast<int>());
  }

  @override
  List<int> toJson(Uint32List object) {
    return object.toList();
  }
}

/// Extension methods for BlockDoc
extension BlockDocExtension on BlockDoc {
  /// Create a copy of this block with updated fields
  BlockDoc copyWithFields({
    String? id,
    String? ty,
    Map<String, String>? attributes,
    String? delta,
    String? parentId,
    String? prevId,
    String? nextId,
    String? oldParentId,
  }) {
    return BlockDoc(
      id: id ?? this.id,
      ty: ty ?? this.ty,
      attributes: attributes ?? Map.from(this.attributes),
      delta: delta ?? this.delta,
      parentId: parentId ?? this.parentId,
      prevId: prevId ?? this.prevId,
      nextId: nextId ?? this.nextId,
      oldParentId: oldParentId ?? this.oldParentId,
    );
  }

  /// Check if this block has a parent
  bool get hasParent => parentId != null && parentId!.isNotEmpty;

  /// Check if this block has a previous sibling
  bool get hasPrevSibling => prevId != null && prevId!.isNotEmpty;

  /// Check if this block has a next sibling
  bool get hasNextSibling => nextId != null && nextId!.isNotEmpty;

  /// Check if this block has text content
  bool get hasText => delta != null && delta!.isNotEmpty;

  /// Get the effective parent ID (defaults to 'root' if null)
  String get effectiveParentId => parentId ?? 'root';
}

/// Extension methods for DocumentState
extension DocumentStateExtension on DocumentState {
  /// Get a block by ID
  BlockDoc? getBlock(String id) => blocks[id];

  /// Check if a block exists
  bool hasBlock(String id) => blocks.containsKey(id);

  /// Get children of a block
  List<String> getChildren(String blockId) => childrenMap[blockId] ?? const [];

  /// Get all descendant IDs of a block (recursive)
  List<String> getDescendants(String blockId) {
    final descendants = <String>[];
    final queue = <String>[blockId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final children = getChildren(currentId);

      for (final childId in children) {
        descendants.add(childId);
        queue.add(childId);
      }
    }

    return descendants;
  }

  /// Get the root block
  BlockDoc? get rootBlock => blocks[rootId];

  /// Count total blocks
  int get blockCount => blocks.length;

  /// Check if document is empty
  bool get isEmpty => blocks.isEmpty;

  /// Check if document is valid
  bool get isValid {
    // Check if root exists
    if (!hasBlock(rootId)) return false;

    // Check if all children references are valid
    for (final children in childrenMap.values) {
      for (final childId in children) {
        if (!hasBlock(childId)) return false;
      }
    }

    return true;
  }

  /// Get all blocks of a specific type
  List<BlockDoc> getBlocksByType(String type) {
    return blocks.values.where((block) => block.ty == type).toList();
  }

  /// Get path to a block from root
  List<String>? getPath(String blockId) {
    if (!hasBlock(blockId)) return null;
    if (blockId == rootId) return [rootId];

    final path = <String>[];
    String? currentId = blockId;

    while (currentId != null && currentId != rootId) {
      path.insert(0, currentId);
      final block = blocks[currentId];
      currentId = block?.parentId;

      // Prevent infinite loops
      if (path.length > blocks.length) return null;
    }

    if (currentId == rootId) {
      path.insert(0, rootId);
      return path;
    }

    return null;
  }
}

/// Extension methods for BlockActionDoc
extension BlockActionDocExtension on BlockActionDoc {
  /// Check if this is an insert action
  bool get isInsert => action == BlockActionTypeDoc.insert;

  /// Check if this is an update action
  bool get isUpdate => action == BlockActionTypeDoc.update;

  /// Check if this is a delete action
  bool get isDelete => action == BlockActionTypeDoc.delete;

  /// Check if this is a move action
  bool get isMove => action == BlockActionTypeDoc.move;

  /// Validate the action
  bool get isValid {
    switch (action) {
      case BlockActionTypeDoc.insert:
        return block.id.isNotEmpty && block.ty.isNotEmpty;
      case BlockActionTypeDoc.update:
        return block.id.isNotEmpty;
      case BlockActionTypeDoc.delete:
        return block.id.isNotEmpty;
      case BlockActionTypeDoc.move:
        return block.id.isNotEmpty &&
            oldPath != null &&
            block.parentId != null &&
            block.oldParentId != null;
    }
  }
}

/// Helper class for creating BlockActionDoc instances
class BlockActionDocBuilder {
  /// Create an insert action
  static BlockActionDoc insert({
    required String id,
    required String type,
    Map<String, String>? attributes,
    String? delta,
    String? parentId,
    String? prevId,
    String? nextId,
    required List<int> path,
  }) {
    return BlockActionDoc(
      action: BlockActionTypeDoc.insert,
      block: BlockDoc(
        id: id,
        ty: type,
        attributes: attributes ?? {},
        delta: delta,
        parentId: parentId,
        prevId: prevId,
        nextId: nextId,
        oldParentId: null,
      ),
      path: Uint32List.fromList(path),
      oldPath: null,
    );
  }

  /// Create an update action
  static BlockActionDoc update({
    required String id,
    required String type,
    Map<String, String>? attributes,
    String? delta,
    required List<int> path,
  }) {
    return BlockActionDoc(
      action: BlockActionTypeDoc.update,
      block: BlockDoc(
        id: id,
        ty: type,
        attributes: attributes ?? {},
        delta: delta,
        parentId: null,
        prevId: null,
        nextId: null,
        oldParentId: null,
      ),
      path: Uint32List.fromList(path),
      oldPath: null,
    );
  }

  /// Create a delete action
  static BlockActionDoc delete({
    required String id,
    String? parentId,
    required List<int> path,
  }) {
    return BlockActionDoc(
      action: BlockActionTypeDoc.delete,
      block: BlockDoc(
        id: id,
        ty: '',
        attributes: {},
        delta: null,
        parentId: parentId,
        prevId: null,
        nextId: null,
        oldParentId: null,
      ),
      path: Uint32List.fromList(path),
      oldPath: null,
    );
  }

  /// Create a move action
  static BlockActionDoc move({
    required String id,
    required String type,
    required String parentId,
    required String oldParentId,
    String? prevId,
    String? nextId,
    required List<int> path,
    required List<int> oldPath,
  }) {
    return BlockActionDoc(
      action: BlockActionTypeDoc.move,
      block: BlockDoc(
        id: id,
        ty: type,
        attributes: {},
        delta: null,
        parentId: parentId,
        prevId: prevId,
        nextId: nextId,
        oldParentId: oldParentId,
      ),
      path: Uint32List.fromList(path),
      oldPath: Uint32List.fromList(oldPath),
    );
  }
}
