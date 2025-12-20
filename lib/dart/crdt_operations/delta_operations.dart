import 'dart:convert';

/// Delta operations for text editing (Quill-like deltas)
/// Replicates the functionality of the Rust delta_ops.rs
class DeltaOperations {
  static const String _insert = 'insert';
  static const String _retain = 'retain';
  static const String _delete = 'delete';
  static const String _attributes = 'attributes';

  /// Apply a delta to text and return the new text
  static Future<String> applyDeltaToText(
    String currentText,
    String deltaJson,
  ) async {
    // Parse the delta
    final List<dynamic> delta = jsonDecode(deltaJson);

    if (delta.isEmpty) {
      return currentText;
    }

    // Apply the delta operations
    return _applyDeltaDiff(currentText, delta);
  }

  /// Apply delta operations to text
  static String _applyDeltaDiff(String text, List<dynamic> delta) {
    final buffer = StringBuffer();
    var textIndex = 0;

    for (final operation in delta) {
      final op = operation as Map<String, dynamic>;

      if (op.containsKey(_insert)) {
        // Insert operation
        final insertText = op[_insert] as String;
        buffer.write(insertText);
      } else if (op.containsKey(_retain)) {
        // Retain operation
        final retainLength = op[_retain] as int;
        final endIndex = textIndex + retainLength;

        if (endIndex > text.length) {
          throw Exception('Retain exceeds text length');
        }

        buffer.write(text.substring(textIndex, endIndex));
        textIndex = endIndex;
      } else if (op.containsKey(_delete)) {
        // Delete operation
        final deleteLength = op[_delete] as int;
        textIndex += deleteLength;

        if (textIndex > text.length) {
          throw Exception('Delete exceeds text length');
        }
      }
    }

    // Append any remaining text
    if (textIndex < text.length) {
      buffer.write(text.substring(textIndex));
    }

    return buffer.toString();
  }

  /// Convert text to delta format
  static String textToDelta(String text) {
    if (text.isEmpty) {
      return jsonEncode([]);
    }

    return jsonEncode([
      {_insert: text},
    ]);
  }

  /// Compute the difference between two texts as a delta
  static String computeTextDelta(String oldText, String newText) {
    if (oldText == newText) {
      return jsonEncode([]);
    }

    // Simple implementation - for production, use a proper diff algorithm
    final delta = <Map<String, dynamic>>[];

    // Find common prefix
    var commonPrefixLength = 0;
    final minLength =
        oldText.length < newText.length ? oldText.length : newText.length;

    while (commonPrefixLength < minLength &&
        oldText[commonPrefixLength] == newText[commonPrefixLength]) {
      commonPrefixLength++;
    }

    // Find common suffix
    var commonSuffixLength = 0;
    while (commonSuffixLength < (minLength - commonPrefixLength) &&
        oldText[oldText.length - 1 - commonSuffixLength] ==
            newText[newText.length - 1 - commonSuffixLength]) {
      commonSuffixLength++;
    }

    // Retain common prefix
    if (commonPrefixLength > 0) {
      delta.add({_retain: commonPrefixLength});
    }

    // Delete the changed part
    final deleteLength =
        oldText.length - commonPrefixLength - commonSuffixLength;
    if (deleteLength > 0) {
      delta.add({_delete: deleteLength});
    }

    // Insert the new part
    final insertStart = commonPrefixLength;
    final insertEnd = newText.length - commonSuffixLength;
    if (insertEnd > insertStart) {
      delta.add({_insert: newText.substring(insertStart, insertEnd)});
    }

    return jsonEncode(delta);
  }

  /// Merge two deltas into one
  static String mergeDeltas(String delta1Json, String delta2Json) {
    final delta1 = jsonDecode(delta1Json) as List<dynamic>;
    final delta2 = jsonDecode(delta2Json) as List<dynamic>;

    if (delta1.isEmpty) return delta2Json;
    if (delta2.isEmpty) return delta1Json;

    // Apply delta1 first, then delta2
    // This is a simplified implementation
    final result = <Map<String, dynamic>>[];
    result.addAll(delta1.cast<Map<String, dynamic>>());
    result.addAll(delta2.cast<Map<String, dynamic>>());

    return jsonEncode(result);
  }

  /// Compose two deltas into one (apply delta2 on top of delta1)
  static String composeDeltas(String delta1Json, String delta2Json) {
    final delta1 = jsonDecode(delta1Json) as List<dynamic>;
    final delta2 = jsonDecode(delta2Json) as List<dynamic>;

    if (delta1.isEmpty) return delta2Json;
    if (delta2.isEmpty) return delta1Json;

    // For now, return a simple concatenation
    // In production, implement proper delta composition
    final result = <Map<String, dynamic>>[];
    result.addAll(delta1.cast<Map<String, dynamic>>());
    result.addAll(delta2.cast<Map<String, dynamic>>());

    return jsonEncode(result);
  }

  /// Transform delta against another delta (for OT-style conflict resolution)
  static String transformDelta(
    String deltaJson,
    String againstJson, {
    bool priority = false,
  }) {
    // This is a simplified implementation
    // For production, implement proper operational transformation
    final delta = jsonDecode(deltaJson) as List<dynamic>;
    return jsonEncode(delta);
  }

  /// Validate a delta
  static bool isValidDelta(String deltaJson) {
    try {
      final delta = jsonDecode(deltaJson);
      if (delta is! List) return false;

      for (final op in delta) {
        if (op is! Map<String, dynamic>) return false;

        final hasInsert = op.containsKey(_insert);
        final hasRetain = op.containsKey(_retain);
        final hasDelete = op.containsKey(_delete);

        // Must have exactly one operation type
        final operationCount =
            (hasInsert ? 1 : 0) + (hasRetain ? 1 : 0) + (hasDelete ? 1 : 0);

        if (operationCount != 1) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Extract plain text from delta
  static String deltaToPlainText(String deltaJson) {
    final delta = jsonDecode(deltaJson) as List<dynamic>;
    final buffer = StringBuffer();

    for (final op in delta) {
      final operation = op as Map<String, dynamic>;
      if (operation.containsKey(_insert)) {
        buffer.write(operation[_insert] as String);
      }
    }

    return buffer.toString();
  }

  /// Create a delta from plain text
  static String plainTextToDelta(String text) {
    if (text.isEmpty) {
      return jsonEncode([]);
    }

    return jsonEncode([
      {_insert: text},
    ]);
  }
}
