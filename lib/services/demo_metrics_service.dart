import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where a recorded result came from. Real-device runs and unit-test/simulated
/// runs are never mixed in the aggregate the judges see.
enum EvidenceSource {
  realDevice,
  simulated;

  String get label => switch (this) {
        EvidenceSource.realDevice => 'Real device',
        EvidenceSource.simulated => 'Simulated (no live API)',
      };
}

/// One end-to-end scenario run. Only non-sensitive test data is stored.
class DemoCaseResult {
  const DemoCaseResult({
    required this.caseId,
    required this.title,
    required this.source,
    required this.completedWithoutHelp,
    required this.expectedEntities,
    required this.missingEntities,
    required this.correctionExpected,
    required this.correctionApplied,
    required this.draftReachedField,
    required this.playbackInterrupted,
    required this.latencyMs,
    this.transcript = '',
    this.draft = '',
    this.recordedAtIso = '',
  });

  final String caseId;
  final String title;
  final EvidenceSource source;
  final bool completedWithoutHelp;
  final List<String> expectedEntities;
  final List<String> missingEntities;

  /// Whether this case is meant to exercise a spoken self-correction.
  final bool correctionExpected;
  final bool correctionApplied;
  final bool draftReachedField;

  /// Null when the case does not exercise playback.
  final bool? playbackInterrupted;
  final int latencyMs;
  final String transcript;
  final String draft;
  final String recordedAtIso;

  bool get entitiesPreserved => missingEntities.isEmpty;

  bool get passed =>
      completedWithoutHelp &&
      entitiesPreserved &&
      (!correctionExpected || correctionApplied) &&
      draftReachedField &&
      (playbackInterrupted ?? true);

  Map<String, dynamic> toJson() => {
        'caseId': caseId,
        'title': title,
        'source': source.name,
        'completedWithoutHelp': completedWithoutHelp,
        'expectedEntities': expectedEntities,
        'missingEntities': missingEntities,
        'correctionExpected': correctionExpected,
        'correctionApplied': correctionApplied,
        'draftReachedField': draftReachedField,
        'playbackInterrupted': playbackInterrupted,
        'latencyMs': latencyMs,
        'transcript': transcript,
        'draft': draft,
        'recordedAtIso': recordedAtIso,
      };

  factory DemoCaseResult.fromJson(Map<String, dynamic> json) => DemoCaseResult(
        caseId: json['caseId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        source: EvidenceSource.values.firstWhere(
          (s) => s.name == json['source'],
          orElse: () => EvidenceSource.simulated,
        ),
        completedWithoutHelp: json['completedWithoutHelp'] as bool? ?? false,
        expectedEntities:
            (json['expectedEntities'] as List?)?.cast<String>() ?? const [],
        missingEntities:
            (json['missingEntities'] as List?)?.cast<String>() ?? const [],
        correctionExpected: json['correctionExpected'] as bool? ?? false,
        correctionApplied: json['correctionApplied'] as bool? ?? false,
        draftReachedField: json['draftReachedField'] as bool? ?? false,
        playbackInterrupted: json['playbackInterrupted'] as bool?,
        latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
        transcript: json['transcript'] as String? ?? '',
        draft: json['draft'] as String? ?? '',
        recordedAtIso: json['recordedAtIso'] as String? ?? '',
      );
}

/// Aggregate shown on the evidence screen.
class DemoAggregate {
  const DemoAggregate({
    required this.total,
    required this.completed,
    required this.entitiesPreserved,
    required this.correctionsApplied,
    required this.correctionsExpected,
    required this.medianLatencyMs,
    required this.worstLatencyMs,
    required this.appSwitches,
  });

  final int total;
  final int completed;
  final int entitiesPreserved;
  final int correctionsApplied;
  final int correctionsExpected;
  final int medianLatencyMs;
  final int worstLatencyMs;

  /// Always zero by construction: the parent never leaves WhatsApp. Shown to
  /// contrast with the copy/paste workflow, not measured empirically.
  final int appSwitches;

  bool get isEmpty => total == 0;

  static const DemoAggregate empty = DemoAggregate(
    total: 0,
    completed: 0,
    entitiesPreserved: 0,
    correctionsApplied: 0,
    correctionsExpected: 0,
    medianLatencyMs: 0,
    worstLatencyMs: 0,
    appSwitches: 0,
  );

  static DemoAggregate from(List<DemoCaseResult> results) {
    if (results.isEmpty) return empty;
    final latencies = results.map((r) => r.latencyMs).toList()..sort();
    final mid = latencies.length ~/ 2;
    final median = latencies.length.isOdd
        ? latencies[mid]
        : ((latencies[mid - 1] + latencies[mid]) / 2).round();

    return DemoAggregate(
      total: results.length,
      completed: results.where((r) => r.completedWithoutHelp).length,
      entitiesPreserved: results.where((r) => r.entitiesPreserved).length,
      correctionsApplied: results
          .where((r) => r.correctionExpected && r.correctionApplied)
          .length,
      correctionsExpected: results.where((r) => r.correctionExpected).length,
      medianLatencyMs: median,
      worstLatencyMs: latencies.last,
      appSwitches: 0,
    );
  }
}

/// Stores recorded demo runs. Real-device and simulated results are kept in
/// separate buckets so the evidence screen can never present one as the other.
class DemoMetricsService {
  DemoMetricsService._internal();

  static final DemoMetricsService _instance = DemoMetricsService._internal();

  factory DemoMetricsService() => _instance;

  static const String _key = 'demo_evidence_v1';

  SharedPreferences? _prefs;
  final List<DemoCaseResult> _results = [];

  List<DemoCaseResult> get results => List.unmodifiable(_results);

  List<DemoCaseResult> bySource(EvidenceSource source) =>
      _results.where((r) => r.source == source).toList(growable: false);

  DemoAggregate aggregateFor(EvidenceSource source) =>
      DemoAggregate.from(bySource(source));

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    _results.clear();
    final raw = _prefs!.getStringList(_key) ?? const [];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map) {
          _results.add(
            DemoCaseResult.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } on FormatException {
        // Skip corrupt rows rather than losing the whole evidence set.
      }
    }
  }

  Future<void> record(DemoCaseResult result) async {
    _prefs ??= await SharedPreferences.getInstance();
    // One stored row per case id per source: a re-run replaces its predecessor
    // so the aggregate reflects the latest attempt, not a growing tally.
    _results.removeWhere(
      (r) => r.caseId == result.caseId && r.source == result.source,
    );
    _results.add(result);
    await _persist();
  }

  Future<void> clear() async {
    _prefs ??= await SharedPreferences.getInstance();
    _results.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs!.setStringList(
      _key,
      _results.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }
}
