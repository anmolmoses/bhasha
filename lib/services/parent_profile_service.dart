import 'package:shared_preferences/shared_preferences.dart';

import '../models/parent_profile.dart';

/// Persists the parent's approved preferences and glossary.
///
/// Nothing message-related is stored here. The profile is small enough to keep
/// as one JSON blob, which keeps migration trivial.
class ParentProfileService {
  ParentProfileService._internal();

  static final ParentProfileService _instance =
      ParentProfileService._internal();

  factory ParentProfileService() => _instance;

  static const String _profileKey = 'parent_profile_v1';

  SharedPreferences? _prefs;
  ParentProfile _cached = const ParentProfile();

  ParentProfile get profile => _cached;

  Future<ParentProfile> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    _cached = ParentProfile.decode(_prefs!.getString(_profileKey));
    return _cached;
  }

  Future<void> save(ParentProfile profile) async {
    _prefs ??= await SharedPreferences.getInstance();
    _cached = profile;
    await _prefs!.setString(_profileKey, profile.encode());
  }

  Future<ParentProfile> update(
    ParentProfile Function(ParentProfile current) mutate,
  ) async {
    final next = mutate(_cached);
    await save(next);
    return next;
  }

  Future<void> addGlossaryEntry(GlossaryEntry entry) async {
    if (!entry.isValid) return;
    final existing = List<GlossaryEntry>.from(_cached.glossary)
      ..removeWhere(
        (g) => g.source.toLowerCase() == entry.source.toLowerCase(),
      )
      ..add(entry);
    await save(_cached.copyWith(glossary: existing));
  }

  Future<void> removeGlossaryEntry(String source) async {
    final existing = List<GlossaryEntry>.from(_cached.glossary)
      ..removeWhere((g) => g.source.toLowerCase() == source.toLowerCase());
    await save(_cached.copyWith(glossary: existing));
  }

  /// Test seam: drops the cache so a fresh [load] re-reads storage. Used to
  /// prove preferences survive a restart.
  void resetCacheForTesting() {
    _prefs = null;
    _cached = const ParentProfile();
  }
}
