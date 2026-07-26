import 'package:flutter/services.dart';

import '../constants/languages.dart';

typedef MethodHandler = Future<dynamic> Function(MethodCall call);

class PlatformService {
  static final PlatformService _instance = PlatformService._internal();
  factory PlatformService() => _instance;
  PlatformService._internal() {
    _ensureChannelInitialized();
  }

  static const platform = MethodChannel('com.yourapp.bhasha/native');

  final Map<String, MethodHandler> _methodHandlers = {};
  bool _channelInitialized = false;

  void _ensureChannelInitialized() {
    if (_channelInitialized) return;
    platform.setMethodCallHandler((call) async {
      final handler = _methodHandlers[call.method];
      if (handler != null) {
        return handler(call);
      }
      return null;
    });
    _channelInitialized = true;
  }

  void registerMethodHandler(String method, MethodHandler handler) {
    _methodHandlers[method] = handler;
  }

  void unregisterMethodHandler(String method) {
    _methodHandlers.remove(method);
  }

  // Overlay service methods
  Future<bool> startOverlayService() async {
    try {
      final result = await platform.invokeMethod('startOverlayService');
      return result as bool;
    } catch (e) {
      print('Error starting overlay service: $e');
      return false;
    }
  }

  Future<bool> stopOverlayService() async {
    try {
      final result = await platform.invokeMethod('stopOverlayService');
      return result as bool;
    } catch (e) {
      print('Error stopping overlay service: $e');
      return false;
    }
  }

  Future<bool> checkOverlayPermission() async {
    try {
      final result = await platform.invokeMethod('checkOverlayPermission');
      return result as bool;
    } catch (e) {
      print('Error checking overlay permission: $e');
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestOverlayPermission');
    } catch (e) {
      print('Error requesting overlay permission: $e');
    }
  }

  // Keyboard methods
  Future<bool> openKeyboardSettings() async {
    try {
      final result = await platform.invokeMethod('openKeyboardSettings');
      return result as bool;
    } catch (e) {
      print('Error opening keyboard settings: $e');
      return false;
    }
  }

  // Accessibility service methods
  Future<bool> checkAccessibilityPermission() async {
    try {
      final result =
          await platform.invokeMethod('checkAccessibilityPermission');
      return result as bool;
    } catch (e) {
      print('Error checking accessibility permission: $e');
      return false;
    }
  }

  Future<void> requestAccessibilityPermission() async {
    try {
      await platform.invokeMethod('requestAccessibilityPermission');
    } catch (e) {
      print('Error requesting accessibility permission: $e');
    }
  }

  // Microphone (hold-to-speak)
  Future<bool> checkMicPermission() async {
    try {
      final result = await platform.invokeMethod('checkMicPermission');
      return result as bool;
    } catch (e) {
      print('Error checking microphone permission: $e');
      return false;
    }
  }

  Future<void> requestMicPermission() async {
    try {
      await platform.invokeMethod('requestMicPermission');
    } catch (e) {
      print('Error requesting microphone permission: $e');
    }
  }

  // Update floating action type
  Future<void> updateFloatingActionType(String actionType) async {
    try {
      await platform
          .invokeMethod('updateFloatingActionType', {'actionType': actionType});
    } catch (e) {
      print('Error updating floating action type: $e');
    }
  }

  /// Hands the bubble everything it needs to draw its own language chip and
  /// picker.
  ///
  /// The overlay runs with no Dart isolate guaranteed to be alive, so it cannot
  /// ask for this on demand — it has to be pushed down whenever the app changes
  /// it, and read from native preferences from then on.
  Future<void> syncLanguageSettings({
    required String sourceLanguage,
    required String targetLanguage,
    required bool autoFlip,
  }) async {
    try {
      await platform.invokeMethod('syncLanguageSettings', {
        'catalog': [
          for (final language in Languages.all)
            '${language.code}|${language.name}|${language.shortLabel}',
        ],
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'autoFlip': autoFlip,
      });
    } catch (e) {
      print('Error syncing language settings: $e');
    }
  }

  Future<bool> checkContextualTranslateEnabled() async {
    try {
      final result =
          await platform.invokeMethod('checkContextualTranslateEnabled');
      return result as bool;
    } catch (e) {
      print('Error checking contextual translation setting: $e');
      return false;
    }
  }

  Future<bool> setContextualTranslateEnabled(bool enabled) async {
    try {
      final result = await platform.invokeMethod(
        'setContextualTranslateEnabled',
        {'enabled': enabled},
      );
      return result as bool;
    } catch (e) {
      print('Error updating contextual translation setting: $e');
      return false;
    }
  }

  Future<bool> checkScreenTranslationEnabled() async {
    try {
      final result =
          await platform.invokeMethod('checkScreenTranslationEnabled');
      return result as bool;
    } catch (e) {
      print('Error checking screen translation setting: $e');
      return false;
    }
  }

  Future<bool> setScreenTranslationEnabled(bool enabled) async {
    try {
      final result = await platform.invokeMethod(
        'setScreenTranslationEnabled',
        {'enabled': enabled},
      );
      return result as bool;
    } catch (e) {
      print('Error updating screen translation setting: $e');
      return false;
    }
  }
}
