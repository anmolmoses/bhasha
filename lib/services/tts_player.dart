import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sarvam_service.dart';

/// Plays Bulbul's WAV chunks in order.
///
/// One shared player, so a new utterance interrupts the previous one instead
/// of overlapping it. Playback is best-effort by design: a malformed chunk is
/// skipped rather than silencing the rest, and a player that never reports
/// completion is abandoned after the clip's own duration plus a grace period,
/// so a stuck platform channel can never wedge the overlay pipeline.
class TtsPlayer {
  TtsPlayer._internal();

  static final TtsPlayer _instance = TtsPlayer._internal();

  factory TtsPlayer() => _instance;

  final AudioPlayer _player = AudioPlayer();

  /// Bumped by every [play] and [stop]; a running loop that no longer matches
  /// it has been superseded and must exit without touching the player.
  int _generation = 0;

  Completer<void>? _pending;

  bool _speaking = false;

  bool get isSpeaking => _speaking;

  /// Plays [audio]'s chunks back to back. Returns when playback finishes or a
  /// newer [play]/[stop] takes over.
  Future<void> play(TtsAudio audio) async {
    final generation = ++_generation;
    _releasePending();
    await _stopQuietly();
    _speaking = true;

    try {
      for (final chunk in audio.wavBase64Chunks) {
        if (generation != _generation) return;

        final Uint8List bytes;
        try {
          bytes = base64Decode(chunk);
        } on FormatException {
          continue;
        }
        if (bytes.isEmpty) continue;

        final done = Completer<void>();
        _pending = done;
        final sub = _player.onPlayerComplete.listen((_) {
          if (!done.isCompleted) done.complete();
        });

        try {
          await _player.play(BytesSource(bytes));
          await done.future.timeout(
            wavDuration(bytes) + const Duration(seconds: 3),
            onTimeout: () {},
          );
        } finally {
          await sub.cancel();
          if (identical(_pending, done)) _pending = null;
        }
      }
    } catch (e) {
      // A playback failure must never take down the flow that triggered it:
      // the translated text is already on screen.
      if (kDebugMode) debugPrint('[tts] playback failed: $e');
    } finally {
      if (generation == _generation) _speaking = false;
    }
  }

  Future<void> stop() async {
    _generation++;
    _speaking = false;
    _releasePending();
    await _stopQuietly();
  }

  void _releasePending() {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<void> _stopQuietly() async {
    try {
      await _player.stop();
    } catch (_) {
      // The player may not be initialised yet (or the platform channel is
      // absent under test); either way there is nothing to stop.
    }
  }

  /// Reads a WAV clip's duration from its own header, used as the ceiling on
  /// how long to wait for the platform to report completion.
  ///
  /// Falls back to 30 seconds - Bulbul's practical clip ceiling - when the
  /// header is missing or lies.
  @visibleForTesting
  static Duration wavDuration(Uint8List bytes) {
    const fallback = Duration(seconds: 30);
    if (bytes.length < 44) return fallback;
    final data = ByteData.sublistView(bytes);
    // 'RIFF' ... 'WAVE' magic.
    if (data.getUint32(0) != 0x52494646 || data.getUint32(8) != 0x57415645) {
      return fallback;
    }
    final byteRate = data.getUint32(28, Endian.little);
    if (byteRate == 0) return fallback;
    final dataBytes = bytes.length - 44;
    final ms = (dataBytes * 1000) ~/ byteRate;
    if (ms <= 0 || ms > fallback.inMilliseconds) return fallback;
    return Duration(milliseconds: ms);
  }
}
