import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_mode.dart';
import '../models/x_reply_style.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  // Keys
  static const String _apiKeyKey = 'openai_api_key';
  static const String _appModeKey = 'app_mode';
  static const String _sourceLangKey = 'source_language';
  static const String _targetLangKey = 'target_language';
  static const String _grammarCheckEnabledKey = 'grammar_check_enabled';
  static const String _firstTimeSetupKey = 'first_time_setup';
  static const String _autoDetectKey = 'auto_detect_language';
  static const String _floatingActionKey = 'floating_action_type';
  static const String _xReplyToneKey = 'x_reply_tone';
  static const String _xReplyLengthKey = 'x_reply_length';
  static const String _xReplyCountKey = 'x_reply_count';
  static const String _xReplyEmojisKey = 'x_reply_emojis';
  static const String _xReplyInstructionsKey = 'x_reply_instructions';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // API Key (Secure Storage)
  Future<void> saveApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyKey, value: apiKey);
  }

  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: _apiKeyKey);
  }

  Future<void> deleteApiKey() async {
    await _secureStorage.delete(key: _apiKeyKey);
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
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

  String getSourceLanguage() {
    return _prefs?.getString(_sourceLangKey) ?? 'Kannada';
  }

  // Target Language
  Future<void> saveTargetLanguage(String language) async {
    await _prefs?.setString(_targetLangKey, language);
  }

  String getTargetLanguage() {
    return _prefs?.getString(_targetLangKey) ?? 'English';
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

  // First Time Setup
  Future<void> setFirstTimeSetupComplete() async {
    await _prefs?.setBool(_firstTimeSetupKey, true);
  }

  bool isFirstTimeSetupComplete() {
    return _prefs?.getBool(_firstTimeSetupKey) ?? false;
  }

  // Floating Action Type (translate, grammar, or x_replies)
  Future<void> saveFloatingActionType(String actionType) async {
    await _prefs?.setString(_floatingActionKey, actionType);
  }

  String getFloatingActionType() {
    return _prefs?.getString(_floatingActionKey) ?? 'translate';
  }

  // X Reply Style
  Future<void> saveXReplyTone(String tone) async {
    await _prefs?.setString(_xReplyToneKey, tone);
  }

  String getXReplyTone() {
    return _prefs?.getString(_xReplyToneKey) ?? 'Warm';
  }

  Future<void> saveXReplyLength(String length) async {
    await _prefs?.setString(_xReplyLengthKey, length);
  }

  String getXReplyLength() {
    return _prefs?.getString(_xReplyLengthKey) ?? 'Short';
  }

  Future<void> saveXReplyCount(int count) async {
    await _prefs?.setInt(_xReplyCountKey, count);
  }

  int getXReplyCount() {
    return _prefs?.getInt(_xReplyCountKey) ?? 4;
  }

  Future<void> saveXReplyIncludeEmojis(bool include) async {
    await _prefs?.setBool(_xReplyEmojisKey, include);
  }

  bool getXReplyIncludeEmojis() {
    return _prefs?.getBool(_xReplyEmojisKey) ?? false;
  }

  Future<void> saveXReplyInstructions(String instructions) async {
    await _prefs?.setString(_xReplyInstructionsKey, instructions);
  }

  String getXReplyInstructions() {
    return _prefs?.getString(_xReplyInstructionsKey) ?? '';
  }

  XReplyStyle getXReplyStyle() {
    return XReplyStyle(
      tone: getXReplyTone(),
      length: getXReplyLength(),
      replyCount: getXReplyCount(),
      includeEmojis: getXReplyIncludeEmojis(),
      customInstructions: getXReplyInstructions(),
    );
  }

  // Clear all data
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs?.clear();
  }
}
