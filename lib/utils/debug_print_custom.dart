import 'package:flutter/foundation.dart';

class DebugConfig {
  static bool _enableDebugPrint = false;
  static bool get enabled => _enableDebugPrint;
  static void setDebugPrintEnabled(bool value) {
    _enableDebugPrint = value;
  }
}

void debugPrintCustom(String text) {
  if (kDebugMode && DebugConfig.enabled) {
    debugPrint(text);
  }
}
