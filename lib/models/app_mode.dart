enum AppMode {
  floatingButton,
  keyboard,
}

extension AppModeExtension on AppMode {
  String get name {
    switch (this) {
      case AppMode.floatingButton:
        return 'Floating Button';
      case AppMode.keyboard:
        return 'Custom Keyboard';
    }
  }

  String get description {
    switch (this) {
      case AppMode.floatingButton:
        return 'System-wide floating button overlay';
      case AppMode.keyboard:
        return 'Integrated keyboard with translation features';
    }
  }

  String toJson() => toString().split('.').last;

  static AppMode fromJson(String json) {
    return AppMode.values.firstWhere(
      (mode) => mode.toJson() == json,
      orElse: () => AppMode.floatingButton,
    );
  }
}
