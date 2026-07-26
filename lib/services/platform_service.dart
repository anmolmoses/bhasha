import 'package:flutter/services.dart';

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

  // Update floating action type
  Future<void> updateFloatingActionType(String actionType) async {
    try {
      await platform
          .invokeMethod('updateFloatingActionType', {'actionType': actionType});
    } catch (e) {
      print('Error updating floating action type: $e');
    }
  }

  // Translation and grammar methods (called from native)
  Future<String> translateText({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    try {
      final result = await platform.invokeMethod('translateText', {
        'text': text,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
      });
      return result as String;
    } catch (e) {
      print('Error translating text: $e');
      return 'Translation error';
    }
  }

  Future<String> checkGrammar({
    required String text,
    required String language,
  }) async {
    try {
      final result = await platform.invokeMethod('checkGrammar', {
        'text': text,
        'language': language,
      });
      return result as String;
    } catch (e) {
      print('Error checking grammar: $e');
      return 'Grammar check error';
    }
  }
}
