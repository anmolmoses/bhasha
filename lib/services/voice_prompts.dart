import 'dart:convert';

import '../models/conversation_context.dart';
import '../models/parent_profile.dart';
import 'sarvam_service.dart';

/// Parsed result of a rewrite/answer call.
class DraftParse {
  const DraftParse({required this.draft, this.clarification});

  final String draft;

  /// A single short Kannada question, set only when a critical fact was
  /// genuinely ambiguous.
  final String? clarification;

  bool get needsClarification =>
      clarification != null && clarification!.trim().isNotEmpty;
}

/// Prompt construction and response parsing.
///
/// Kept free of I/O so every rule below is directly testable.
class VoicePrompts {
  const VoicePrompts._();

  static const String _entityRule =
      'Never change, drop, or invent: personal names, place names, medicine '
      'names, organisation names, dates, weekdays, times, amounts of money, '
      'quantities, phone numbers, and addresses. Copy them exactly as spoken. '
      'Preserve negation ("not", "cannot", "will not") exactly.';

  static const String _correctionRule =
      'The speaker often corrects themselves mid-sentence. When a value is '
      'stated and then replaced (for example "Tuesday, no, Wednesday" or '
      '"five hundred... actually six hundred"), keep ONLY the final corrected '
      'value and silently drop the earlier one.';

  static const String _inventionRule =
      'Never invent a detail that was not spoken. If a critical fact needed to '
      'make the message usable is genuinely missing or ambiguous, do not guess: '
      'return a clarification question instead of a draft.';

  static const String _jsonRule =
      'Reply with ONLY a JSON object, no code fences and no commentary, shaped '
      'exactly as: {"draft": string, "clarification_kn": string or null}. '
      'Set "clarification_kn" to null whenever you can produce a usable draft. '
      'When you set it, make it ONE short question written in Kannada script '
      'and set "draft" to "".';

  /// Turns a rough spoken transcript into a concise message in the parent's
  /// reply language.
  static List<ChatMessage> replyRewrite({
    required String transcript,
    required ParentProfile profile,
  }) {
    final glossary = profile.glossaryPromptBlock;
    final system = StringBuffer()
      ..writeln(
        'You rewrite a parent\'s spoken words into a short message they can '
        'send on WhatsApp. You are a faithful scribe, not an assistant: never '
        'answer, advise, or add information.',
      )
      ..writeln()
      ..writeln('Rules:')
      ..writeln('- $_entityRule')
      ..writeln('- $_correctionRule')
      ..writeln('- $_inventionRule')
      ..writeln(
        '- Remove filler ("umm", "you know", repeated words) without changing '
        'meaning.',
      )
      ..writeln(
        '- The speech may mix Kannada and English. Understand both; write the '
        'result only in English.',
      )
      ..writeln('- Keep it to one or two short sentences.')
      ..writeln('- ${profile.tone.promptHint}')
      ..writeln('- Do not add greetings or signatures that were not spoken.');
    if (glossary.isNotEmpty) {
      system
        ..writeln()
        ..writeln(glossary);
    }
    system
      ..writeln()
      ..writeln(_jsonRule);

    return [
      ChatMessage.system(system.toString().trim()),
      ChatMessage.user('Spoken words:\n$transcript'),
    ];
  }

  /// Answers a spoken follow-up strictly from the captured message.
  static List<ChatMessage> groundedAnswer({
    required String question,
    required ConversationContext context,
    required ParentProfile profile,
  }) {
    final grounding = context.groundingBlock();
    final system = StringBuffer()
      ..writeln(
        'You answer a parent\'s question about ONE message they received. '
        'The message below is your only source of information.',
      )
      ..writeln()
      ..writeln('Rules:')
      ..writeln(
        '- Use only facts present in the message. Never use outside knowledge '
        'and never guess.',
      )
      ..writeln(
        '- If the message does not contain the answer, say so plainly in '
        'Kannada. Do not speculate.',
      )
      ..writeln('- $_entityRule')
      ..writeln('- Answer in Kannada script, in one or two short sentences.')
      ..writeln('- Do not give medical, legal, or financial advice.')
      ..writeln()
      ..writeln(grounding);

    return [
      ChatMessage.system(system.toString().trim()),
      ChatMessage.user(question),
    ];
  }

  /// Builds a reply draft that may reference the captured message
  /// ("that day", "the same amount", "tell them yes").
  static List<ChatMessage> contextualReply({
    required String transcript,
    required ConversationContext context,
    required ParentProfile profile,
  }) {
    final glossary = profile.glossaryPromptBlock;
    final grounding = context.groundingBlock();
    final system = StringBuffer()
      ..writeln(
        'You rewrite a parent\'s spoken reply into a short English WhatsApp '
        'message. A message they received is provided for reference ONLY.',
      )
      ..writeln()
      ..writeln('Rules:')
      ..writeln(
        '- Use the received message only to resolve references such as "that '
        'day", "the same amount", or "tell them yes". Copy the resolved value '
        'exactly from the message.',
      )
      ..writeln(
        '- Do not restate or summarise the received message. Write only what '
        'the parent wants to say.',
      )
      ..writeln('- $_entityRule')
      ..writeln('- $_correctionRule')
      ..writeln('- $_inventionRule')
      ..writeln('- ${profile.tone.promptHint}');
    if (glossary.isNotEmpty) {
      system
        ..writeln()
        ..writeln(glossary);
    }
    if (grounding.isNotEmpty) {
      system
        ..writeln()
        ..writeln('FOR REFERENCE ONLY:')
        ..writeln(grounding);
    }
    system
      ..writeln()
      ..writeln(_jsonRule);

    return [
      ChatMessage.system(system.toString().trim()),
      ChatMessage.user('Spoken reply:\n$transcript'),
    ];
  }

  /// Tolerant parser: models occasionally wrap JSON in fences or prose.
  ///
  /// Falls back to treating the whole response as the draft rather than
  /// failing the flow, because a usable draft beats an error for the parent.
  static DraftParse parseDraft(String raw) {
    final cleaned = _stripFences(raw).trim();

    final candidate = _firstJsonObject(cleaned);
    if (candidate != null) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map) {
          final draft = (decoded['draft'] as String?)?.trim() ?? '';
          final clarification =
              (decoded['clarification_kn'] as String?)?.trim();
          return DraftParse(
            draft: draft,
            clarification: (clarification == null ||
                    clarification.isEmpty ||
                    clarification == 'null')
                ? null
                : clarification,
          );
        }
      } on FormatException {
        // Fall through to plain-text handling.
      }
    }

    return DraftParse(draft: cleaned);
  }

  static String _stripFences(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1) {
        text = text.substring(firstNewline + 1);
      }
      final closing = text.lastIndexOf('```');
      if (closing != -1) {
        text = text.substring(0, closing);
      }
    }
    return text;
  }

  /// Extracts the first balanced `{...}` span so leading prose does not break
  /// decoding.
  static String? _firstJsonObject(String text) {
    final start = text.indexOf('{');
    if (start == -1) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final char = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }
}

/// Critical-entity extraction used by the evidence screen and tests to check
/// that a draft did not silently drop a number, time, or name.
class EntityCheck {
  const EntityCheck._();

  static final RegExp _time = RegExp(
    r'\b\d{1,2}[:.]\d{2}\s*(?:am|pm)?\b|\b\d{1,2}\s*(?:am|pm)\b',
    caseSensitive: false,
  );
  static final RegExp _phone = RegExp(r'\b(?:\+91[\s-]?)?\d{10}\b');
  static final RegExp _money = RegExp(
    r'(?:rs\.?|inr|₹)\s*\d[\d,]*(?:\.\d+)?|\b\d[\d,]*(?:\.\d+)?\s*(?:rupees|rs\b)',
    caseSensitive: false,
  );
  static final RegExp _weekday = RegExp(
    r'\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    caseSensitive: false,
  );
  static final RegExp _date = RegExp(
    r'\b\d{1,2}(?:st|nd|rd|th)?\s+(?:january|february|march|april|may|june|july|august|september|october|november|december)\b'
    r'|\b(?:january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}\b'
    r'|\b\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?\b',
    caseSensitive: false,
  );

  /// Returns normalised entity tokens found in [text].
  static Set<String> extract(String text) {
    final found = <String>{};
    for (final pattern in [_phone, _money, _time, _date, _weekday]) {
      for (final match in pattern.allMatches(text)) {
        found.add(_normalise(match.group(0)!));
      }
    }
    return found;
  }

  /// Entities present in [expected] but missing from [actual].
  static Set<String> missingFrom({
    required String expected,
    required String actual,
  }) {
    final actualEntities = extract(actual);
    return extract(expected).difference(actualEntities);
  }

  static String _normalise(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[\s,]'), '');
}
