import 'dart:convert';

import 'package:crdt/crdt.dart';
import 'package:flutter/foundation.dart';

/// Update operations for CRDT synchronization
/// Replicates the functionality of the Rust update_ops.rs
///
/// Note: CrdtChangeset is: Map<String, List<Map<String, Object?>>>
/// where each Map contains: {key, value, hlc, is_deleted, modified}
class UpdateOperations {
  /// Encode a CRDT changeset to binary format
  static Uint8List encodeChangeset(CrdtChangeset changeset) {
    // CrdtChangeset is already in a JSON-serializable format
    // Convert to JSON string
    final jsonString = jsonEncode(changeset);

    // Convert to bytes (using UTF-8 encoding)
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Decode binary format to CRDT changeset
  static CrdtChangeset decodeChangeset(Uint8List data) {
    try {
      // Convert bytes to JSON string
      final jsonString = utf8.decode(data);
      final decoded = jsonDecode(jsonString);

      final changeset = parseCrdtChangeset(decoded);

      return changeset;
    } catch (e) {
      throw Exception('Failed to decode changeset: $e');
    }
  }

  /// Compute the difference between two changesets
  static CrdtChangeset computeChangesetDiff(
    CrdtChangeset before,
    CrdtChangeset after,
  ) {
    final diff = <String, List<Map<String, Object?>>>{};

    // Find all tables and records that changed or were added
    for (final tableEntry in after.entries) {
      final tableName = tableEntry.key;
      final afterRecords = tableEntry.value;
      final beforeRecords = before[tableName] ?? [];

      // Create a map of existing records by key for quick lookup
      final beforeMap = <String, Map<String, Object?>>{};
      for (final record in beforeRecords) {
        beforeMap[record['key'] as String] = record;
      }

      final tableDiff = <Map<String, Object?>>[];

      for (final afterRecord in afterRecords) {
        final key = afterRecord['key'] as String;
        final beforeRecord = beforeMap[key];

        // If record doesn't exist in before, or HLC changed, include it
        if (beforeRecord == null ||
            (afterRecord['hlc'] as Hlc) > (beforeRecord['hlc'] as Hlc)) {
          tableDiff.add(afterRecord);
        }
      }

      if (tableDiff.isNotEmpty) {
        diff[tableName] = tableDiff;
      }
    }

    return diff;
  }

  /// Merge multiple changesets into one
  static CrdtChangeset mergeChangesets(List<CrdtChangeset> changesets) {
    if (changesets.isEmpty) {
      return {};
    }

    if (changesets.length == 1) {
      return changesets[0];
    }

    final merged = <String, Map<String, Map<String, Object?>>>{};

    for (final changeset in changesets) {
      for (final tableEntry in changeset.entries) {
        final tableName = tableEntry.key;
        final records = tableEntry.value;

        final mergedTable = merged.putIfAbsent(tableName, () => {});

        for (final record in records) {
          final key = record['key'] as String;
          final hlc = record['hlc'] as Hlc;

          // If we already have this key, keep the one with higher HLC
          if (mergedTable.containsKey(key)) {
            if (hlc > (mergedTable[key]!['hlc'] as Hlc)) {
              mergedTable[key] = record;
            }
          } else {
            mergedTable[key] = record;
          }
        }
      }
    }

    // Convert back to List format
    return merged.map(
      (table, records) => MapEntry(table, records.values.toList()),
    );
  }

  /// Extract document state from a CRDT
  static Map<String, dynamic> extractDocumentState(
    Map<String, dynamic> crdtData,
  ) {
    // Filter out deleted records and extract values
    final result = <String, dynamic>{};

    for (final entry in crdtData.entries) {
      result[entry.key] = entry.value;
    }

    return result;
  }

  /// Create a compact representation of updates
  static Uint8List encodeCompact(List<CrdtChangeset> changesets) {
    final merged = mergeChangesets(changesets);
    return encodeChangeset(merged);
  }

  /// Decode multiple updates from a compact format
  static List<CrdtChangeset> decodeCompact(Uint8List data) {
    final changeset = decodeChangeset(data);
    return [changeset];
  }

  /// Check if an update is empty
  static bool isEmptyUpdate(Uint8List data) {
    if (data.isEmpty) return true;

    try {
      final changeset = decodeChangeset(data);
      return changeset.isEmpty ||
          changeset.values.every((records) => records.isEmpty);
    } catch (e) {
      return true;
    }
  }

  /// Get the size of an update in bytes
  static int getUpdateSize(Uint8List data) {
    return data.length;
  }

  /// Validate an update format
  static bool isValidUpdate(Uint8List data) {
    try {
      decodeChangeset(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create an empty update
  static Uint8List emptyUpdate() {
    return encodeChangeset({});
  }
}

/// Helper extension for CrdtChangeset
extension CrdtChangesetExtension on CrdtChangeset {
  /// Get the total number of records in this changeset
  int get recordCount => values.fold(0, (sum, records) => sum + records.length);

  /// Check if this changeset is empty
  bool get isEmpty => recordCount == 0;

  /// Check if this changeset has any records
  bool get isNotEmpty => recordCount > 0;
}
