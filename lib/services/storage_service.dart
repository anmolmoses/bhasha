import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/languages.dart';
import '../models/app_mode.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  // Keys
  static const String _sarvamApiKeyKey = 'sarvam_api_key';
  static const String _legacyOpenAiOcrKeyKey = 'openai_ocr_api_key';
  static const String _legacyOpenAiKeyKey = 'openai_api_key';
  static const String _appModeKey = 'app_mode';
  static const String _sourceLangKey = 'source_language';
  static const String _targetLangKey = 'target_language';
  static const String _grammarCheckEnabledKey = 'grammar_check_enabled';
  static const String _firstTimeSetupKey = 'first_time_setup';
  static const String _autoDetectKey = 'auto_detect_language';
  static const String _autoFlipKey = 'auto_flip_language_pair';
  static const String _floatingActionKey = 'floating_action_type';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _purgeLegacyOpenAiKeys();
  }

  /// Screen OCR now runs on Sarvam Vision, so no OpenAI credential is used
  /// anywhere. Delete anything an earlier build stored rather than leaving a
  /// live key sitting in the keystore.
  Future<void> _purgeLegacyOpenAiKeys() async {
    try {
      await _secureStorage.delete(key: _legacyOpenAiOcrKeyKey);
      await _secureStorage.delete(key: _legacyOpenAiKeyKey);
    } catch (_) {
      // A keystore failure must never block app startup.
    }
  }

  // Sarvam API Key (Secure Storage)
  Future<void> saveSarvamApiKey(String apiKey) async {
    await _secureStorage.write(key: _sarvamApiKeyKey, value: apiKey.trim());
  }

  Future<String?> getSarvamApiKey() async {
    return await _secureStorage.read(key: _sarvamApiKeyKey);
  }

  Future<void> deleteSarvamApiKey() async {
    await _secureStorage.delete(key: _sarvamApiKeyKey);
  }

  Future<bool> hasSarvamApiKey() async {
    final key = await getSarvamApiKey();
    return key != null && key.isNotEmpty;
  }

  // App Mode
  Future<void> saveAppMode(AppMode mode) async {
    await _prefs?.setString(_appModeKey, mode.toJson());
  }

  AppMode getAppMode() {
    final modeStr = _prefs?.getString(_appModeKey);
    if (modeStr == null) return AppMode.floatingButton;
    return AppModeExtension.fromJson(modeStr);
  }

  // Source Language
  Future<void> saveSourceLanguage(String language) async {
    await _prefs?.setString(_sourceLangKey, language);
  }

  /// Falls back to Kannada when the stored value is a language Sarvam does not
  /// support (possible after upgrading from the OpenAI build, which offered 35).
  String getSourceLanguage() {
    final stored = _prefs?.getString(_sourceLangKey);
    if (stored != null && Languages.isSupported(stored)) return stored;
    return Languages.defaultSourceName;
  }

  // Target Language
  Future<void> saveTargetLanguage(String language) async {
    await _prefs?.setString(_targetLangKey, language);
  }

  String getTargetLanguage() {
    final stored = _prefs?.getString(_targetLangKey);
    if (stored != null && Languages.isSupported(stored)) return stored;
    return Languages.defaultTargetName;
  }

  // Grammar Check Enabled
  Future<void> saveGrammarCheckEnabled(bool enabled) async {
    await _prefs?.setBool(_grammarCheckEnabledKey, enabled);
  }

  bool getGrammarCheckEnabled() {
    return _prefs?.getBool(_grammarCheckEnabledKey) ?? true;
  }

  // Auto Detect Language
  Future<void> saveAutoDetect(bool enabled) async {
    await _prefs?.setBool(_autoDetectKey, enabled);
  }

  bool getAutoDetect() {
    return _prefs?.getBool(_autoDetectKey) ?? false;
  }

  // Auto-flip between the two working languages
  Future<void> saveAutoFlip(bool enabled) async {
    await _prefs?.setBool(_autoFlipKey, enabled);
  }

  /// On by default: the common case is a parent moving between the same two
  /// languages all day, and having to open Settings to reverse the direction
  /// was the reason they left the app they were in.
  bool getAutoFlip() {
    return _prefs?.getBool(_autoFlipKey) ?? true;
  }

  // First Time Setup
  Future<void> setFirstTimeSetupComplete() async {
    await _prefs?.setBool(_firstTimeSetupKey, true);
  }

  bool isFirstTimeSetupComplete() {
    return _prefs?.getBool(_firstTimeSetupKey) ?? false;
  }

  // Floating Action Type (translate or grammar)
  Future<void> saveFloatingActionType(String actionType) async {
    await _prefs?.setString(_floatingActionKey, actionType);
  }

  String getFloatingActionType() {
    final stored = _prefs?.getString(_floatingActionKey);
    // 'x_replies' was removed with the vision feature; map it back to the
    // default so an upgraded install does not start on a dead action.
    if (stored == 'translate' || stored == 'grammar') return stored!;
    return 'translate';
  }

  // Clear all data
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs?.clear();
  }
}
