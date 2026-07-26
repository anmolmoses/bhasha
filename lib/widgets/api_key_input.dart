import 'package:flutter/material.dart';

import '../l10n/parent_strings.dart';
import '../models/sarvam_error.dart';
import '../services/sarvam_service.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';
import 'primary_button.dart';
import 'section_header.dart';

/// Result of the post-save connection check, shown inline.
enum _CheckState { none, checking, ok, failed }

class ApiKeyInput extends StatefulWidget {
  final String? initialApiKey;

  /// Awaited before the connection check runs, so the key is in secure storage
  /// by the time [SarvamService] reads it.
  final Future<void> Function(String apiKey) onApiKeySaved;

  const ApiKeyInput({
    super.key,
    this.initialApiKey,
    required this.onApiKeySaved,
  });

  @override
  State<ApiKeyInput> createState() => _ApiKeyInputState();
}

class _ApiKeyInputState extends State<ApiKeyInput> {
  late TextEditingController _controller;
  bool _obscureText = true;
  bool _isSaving = false;
  _CheckState _check = _CheckState.none;
  String _checkMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialApiKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Paste your Sarvam API key before saving.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _check = _CheckState.checking;
      _checkMessage = '';
    });

    await widget.onApiKeySaved(key);

    // A real round trip to Sarvam: a key that saves but does not work is worse
    // than no key, because it fails later inside WhatsApp.
    String message;
    _CheckState state;
    try {
      await SarvamService.shared.verifyKey();
      state = _CheckState.ok;
      message = 'Key saved and verified with Sarvam.';
    } on SarvamException catch (e) {
      state = _CheckState.failed;
      message = ParentStrings.localize(e.parentMessage);
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
        _check = state;
        _checkMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            headline: 'Sarvam API key',
            subtitle:
                'Create one at dashboard.sarvam.ai → API keys and paste it here.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            obscureText: _obscureText,
            decoration: InputDecoration(
              hintText: 'sk_...',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your key is encrypted on this device. It is sent only to Sarvam, '
                    'and only for actions you start yourself.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (_check != _CheckState.none) ...[
            const SizedBox(height: 14),
            _buildCheckRow(context),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: _isSaving ? 'Checking...' : 'Save and check connection',
            icon: Icons.save_rounded,
            onPressed: _isSaving ? null : _saveKey,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(BuildContext context) {
    final (icon, color) = switch (_check) {
      _CheckState.checking => (Icons.sync_rounded, AppColors.textSecondary),
      _CheckState.ok => (Icons.check_circle_rounded, Colors.green),
      _CheckState.failed => (Icons.error_outline_rounded, AppColors.accent),
      _CheckState.none => (Icons.circle_outlined, AppColors.textSecondary),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _check == _CheckState.checking
                ? 'Checking your key with Sarvam...'
                : _checkMessage,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
