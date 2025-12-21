import 'dart:convert';

import 'package:flutter/foundation.dart';

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
      debugPrint('Operation: $op');

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

  /// Compose two deltas (currentDelta ∘ newDelta = resultDelta)
  static List<Map<String, dynamic>> composeDelta(
    List<Map<String, dynamic>> currentDelta,
    List<Map<String, dynamic>> newDelta,
  ) {
    if (currentDelta.isEmpty) return List.from(newDelta);
    if (newDelta.isEmpty) return List.from(currentDelta);

    final result = <Map<String, dynamic>>[];
    var currentOps = List<Map<String, dynamic>>.from(currentDelta);
    var newOps = List<Map<String, dynamic>>.from(newDelta);

    var currentIndex = 0;
    var newIndex = 0;

    while (currentIndex < currentOps.length || newIndex < newOps.length) {
      final currentOp =
          currentIndex < currentOps.length ? currentOps[currentIndex] : null;
      final newOp = newIndex < newOps.length ? newOps[newIndex] : null;

      if (newOp != null && newOp.containsKey(_insert)) {
        result.add(Map.from(newOp));
        newIndex++;
      } else if (currentOp != null && currentOp.containsKey(_insert)) {
        if (newOp != null && newOp.containsKey(_retain)) {
          final insertText = currentOp[_insert] as String;
          final insertLen = insertText.length;
          final retainLen = newOp[_retain] as int;

          if (retainLen >= insertLen) {
            final resultOp = Map<String, dynamic>.from(currentOp);
            if (newOp.containsKey(_attributes)) {
              final currentAttrs =
                  (resultOp[_attributes] as Map<String, dynamic>?) ??
                  (currentOp.containsKey(_attributes)
                      ? Map<String, dynamic>.from(currentOp[_attributes] as Map)
                      : <String, dynamic>{});
              final newAttrs = Map<String, dynamic>.from(
                newOp[_attributes] as Map,
              );
              resultOp[_attributes] = <String, dynamic>{
                ...currentAttrs,
                ...newAttrs,
              };
            }
            result.add(resultOp);
            currentIndex++;

            if (retainLen > insertLen) {
              newOps[newIndex] = {_retain: retainLen - insertLen};
              if (newOp.containsKey(_attributes)) {
                newOps[newIndex][_attributes] = newOp[_attributes];
              }
            } else {
              newIndex++;
            }
          } else {
            final splitText = insertText.substring(0, retainLen);
            final resultOp = <String, dynamic>{_insert: splitText};

            if (currentOp.containsKey(_attributes) ||
                newOp.containsKey(_attributes)) {
              final currentAttrs =
                  currentOp.containsKey(_attributes)
                      ? Map<String, dynamic>.from(currentOp[_attributes] as Map)
                      : <String, dynamic>{};
              final newAttrs =
                  newOp.containsKey(_attributes)
                      ? Map<String, dynamic>.from(newOp[_attributes] as Map)
                      : <String, dynamic>{};
              resultOp[_attributes] = <String, dynamic>{
                ...currentAttrs,
                ...newAttrs,
              };
            }
            result.add(resultOp);

            currentOps[currentIndex] = {
              _insert: insertText.substring(retainLen),
            };
            if (currentOp.containsKey(_attributes)) {
              currentOps[currentIndex][_attributes] = currentOp[_attributes];
            }
            newIndex++;
          }
        } else if (newOp != null && newOp.containsKey(_delete)) {
          final insertLen = (currentOp[_insert] as String).length;
          final deleteLen = newOp[_delete] as int;

          if (deleteLen >= insertLen) {
            currentIndex++;
            if (deleteLen > insertLen) {
              newOps[newIndex] = {_delete: deleteLen - insertLen};
            } else {
              newIndex++;
            }
          } else {
            final insertText = currentOp[_insert] as String;
            currentOps[currentIndex] = {
              _insert: insertText.substring(deleteLen),
            };
            if (currentOp.containsKey(_attributes)) {
              currentOps[currentIndex][_attributes] = currentOp[_attributes];
            }
            newIndex++;
          }
        } else {
          result.add(Map.from(currentOp));
          currentIndex++;
        }
      } else if (currentOp != null && currentOp.containsKey(_retain)) {
        if (newOp != null && newOp.containsKey(_retain)) {
          final currentRetain = currentOp[_retain] as int;
          final newRetain = newOp[_retain] as int;
          final minRetain =
              currentRetain < newRetain ? currentRetain : newRetain;

          final resultOp = <String, dynamic>{_retain: minRetain};

          if (currentOp.containsKey(_attributes) ||
              newOp.containsKey(_attributes)) {
            final currentAttrs =
                currentOp.containsKey(_attributes)
                    ? Map<String, dynamic>.from(currentOp[_attributes] as Map)
                    : <String, dynamic>{};
            final newAttrs =
                newOp.containsKey(_attributes)
                    ? Map<String, dynamic>.from(newOp[_attributes] as Map)
                    : <String, dynamic>{};
            final mergedAttrs = <String, dynamic>{...currentAttrs, ...newAttrs};
            if (mergedAttrs.isNotEmpty) {
              resultOp[_attributes] = mergedAttrs;
            }
          }

          result.add(resultOp);

          if (currentRetain > minRetain) {
            currentOps[currentIndex] = {_retain: currentRetain - minRetain};
            if (currentOp.containsKey(_attributes)) {
              currentOps[currentIndex][_attributes] = currentOp[_attributes];
            }
          } else {
            currentIndex++;
          }

          if (newRetain > minRetain) {
            newOps[newIndex] = {_retain: newRetain - minRetain};
            if (newOp.containsKey(_attributes)) {
              newOps[newIndex][_attributes] = newOp[_attributes];
            }
          } else {
            newIndex++;
          }
        } else if (newOp != null && newOp.containsKey(_delete)) {
          final retainLen = currentOp[_retain] as int;
          final deleteLen = newOp[_delete] as int;
          final minLen = retainLen < deleteLen ? retainLen : deleteLen;

          result.add(<String, dynamic>{_delete: minLen});

          if (retainLen > minLen) {
            currentOps[currentIndex] = {_retain: retainLen - minLen};
            if (currentOp.containsKey(_attributes)) {
              currentOps[currentIndex][_attributes] = currentOp[_attributes];
            }
          } else {
            currentIndex++;
          }

          if (deleteLen > minLen) {
            newOps[newIndex] = {_delete: deleteLen - minLen};
          } else {
            newIndex++;
          }
        } else {
          result.add(Map.from(currentOp));
          currentIndex++;
        }
      } else if (currentOp != null && currentOp.containsKey(_delete)) {
        if (newOp != null && newOp.containsKey(_retain)) {
          result.add(Map.from(currentOp));
          currentIndex++;

          final deleteLen = currentOp[_delete] as int;
          final retainLen = newOp[_retain] as int;
          if (retainLen > deleteLen) {
            newOps[newIndex] = {_retain: retainLen - deleteLen};
            if (newOp.containsKey(_attributes)) {
              newOps[newIndex][_attributes] = newOp[_attributes];
            }
          } else {
            newIndex++;
          }
        } else if (newOp != null && newOp.containsKey(_delete)) {
          final currentDelete = currentOp[_delete] as int;
          final newDelete = newOp[_delete] as int;
          result.add(<String, dynamic>{_delete: currentDelete + newDelete});
          currentIndex++;
          newIndex++;
        } else {
          result.add(Map.from(currentOp));
          currentIndex++;
        }
      } else {
        if (currentOp != null) currentIndex++;
        if (newOp != null) newIndex++;
      }
    }

    return _cleanupDelta(result);
  }

  static List<Map<String, dynamic>> _cleanupDelta(
    List<Map<String, dynamic>> delta,
  ) {
    if (delta.isEmpty) return delta;

    final result = <Map<String, dynamic>>[];
    Map<String, dynamic>? lastOp;

    for (final op in delta) {
      if (lastOp != null && _canMerge(lastOp, op)) {
        lastOp = _mergeOps(lastOp, op);
      } else {
        if (lastOp != null) result.add(lastOp);
        lastOp = Map.from(op);
      }
    }

    if (lastOp != null) result.add(lastOp);
    return result;
  }

  static bool _canMerge(Map<String, dynamic> op1, Map<String, dynamic> op2) {
    if (op1.containsKey(_insert) && op2.containsKey(_insert)) {
      return jsonEncode(op1[_attributes] ?? {}) ==
          jsonEncode(op2[_attributes] ?? {});
    }
    if (op1.containsKey(_retain) && op2.containsKey(_retain)) {
      return jsonEncode(op1[_attributes] ?? {}) ==
          jsonEncode(op2[_attributes] ?? {});
    }
    if (op1.containsKey(_delete) && op2.containsKey(_delete)) {
      return true;
    }
    return false;
  }

  static Map<String, dynamic> _mergeOps(
    Map<String, dynamic> op1,
    Map<String, dynamic> op2,
  ) {
    if (op1.containsKey(_insert) && op2.containsKey(_insert)) {
      final result = <String, dynamic>{_insert: op1[_insert] + op2[_insert]};
      if (op1.containsKey(_attributes)) result[_attributes] = op1[_attributes];
      return result;
    }
    if (op1.containsKey(_retain) && op2.containsKey(_retain)) {
      final result = <String, dynamic>{
        _retain: (op1[_retain] as int) + (op2[_retain] as int),
      };
      if (op1.containsKey(_attributes)) result[_attributes] = op1[_attributes];
      return result;
    }
    if (op1.containsKey(_delete) && op2.containsKey(_delete)) {
      return <String, dynamic>{
        _delete: (op1[_delete] as int) + (op2[_delete] as int),
      };
    }
    return op1;
  }

  static String deltaToJson(List<Map<String, dynamic>> delta) =>
      jsonEncode(delta);

  static List<Map<String, dynamic>> jsonToDelta(String json) {
    if (json.isEmpty || json == '[]') return [];
    final List<dynamic> parsed = jsonDecode(json);
    return parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
