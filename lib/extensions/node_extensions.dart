import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/dart/document_types.dart';
import 'package:flutter/foundation.dart';

extension DocumentComparison on Document {
  /// Deep comparison of documents based on structure and content
  bool isContentEqual(Document other) {
    if (identical(this, other)) return true;

    // Compare JSON representations (most reliable but less efficient)
    return jsonEncode(toJson()) == jsonEncode(other.toJson());
  }
}

extension AttributesExtension on Attributes {
  Map<String, String> toMap() {
    return map((key, value) => MapEntry(key, value.toString()));
  }
}

Node jsonToNode(Map<String, dynamic> json) {
  final type = json['type'] as String;
  final data = json['data'] as Map<String, dynamic>;
  final childrenJson = json['children'] as List<dynamic>;

  final children =
      childrenJson
          .map((child) => jsonToNode(child as Map<String, dynamic>))
          .toList();

  return Node(type: type, attributes: data, children: children);
}

//Create extension on Map<String, String> to convert to Attributes and try to parse the string as int or float and make it number if possible
extension Attributes2Extension on Map<String, String> {
  Attributes toAttributes() {
    final result = <String, dynamic>{};
    for (final entry in entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == 'true') {
        result[key] = true;
      } else if (value == 'false') {
        result[key] = false;
      } else if (value == 'null') {
        result[key] = null;
      } else {
        final number = num.tryParse(value);
        if (number != null) {
          result[key] = number;
        } else {
          result[key] = value;
        }
      }
    }

    return result;
  }
}

extension BlockExtension on BlockDoc {
  Node toNode({required List<Node> children}) {
    try {
      final deltaString =
          delta != null ? safeJsonDecode<List<dynamic>>(delta) : '';
      final convertedAttributes = attributes.toAttributes();
      if (deltaString != '') {
        convertedAttributes['delta'] = deltaString;
      }
      return Node(
        id: id,
        children: children,
        type: ty,
        attributes: convertedAttributes,
      );
    } catch (e, st) {
      debugPrint('❌ toNode failed for block $id ($ty)');
      debugPrint('$e');
      rethrow;
    }
  }

  T? safeJsonDecode<T>(String? source) {
    if (source == null || source.isEmpty) return null;

    try {
      dynamic decoded = jsonDecode(source);

      while (decoded is String &&
          (decoded.startsWith('[') || decoded.startsWith('{'))) {
        decoded = jsonDecode(decoded);
      }

      if (decoded is T) {
        return decoded;
      } else {
        debugPrint(
          'Warning: Decoded JSON type ${decoded.runtimeType} does not match expected type $T',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error decoding JSON: $e');
      return null;
    }
  }
}
