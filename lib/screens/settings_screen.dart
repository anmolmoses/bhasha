import 'package:flutter/material.dart';

import '../services/openai_service.dart';
import '../services/platform_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/api_key_input.dart';
import '../widgets/glass_card.dart';
import '../widgets/language_picker.dart';
import '../widgets/section_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _storage = StorageService();
  final _openai = OpenAIService();
  final _platform = PlatformService();
  final _xReplyInstructionsController = TextEditingController();

  late String _sourceLang;
  late String _targetLang;
  late bool _autoDetect;
  String? _apiKey;
  bool _overlayServiceRunning = false;
  bool _overlayPermissionGranted = false;
  bool _accessibilityEnabled = false;
  String _floatingActionType = 'translate';
  String _xReplyTone = 'Warm';
  String _xReplyLength = 'Short';
  int _xReplyCount = 4;
  bool _xReplyIncludeEmojis = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh permissions when app resumes from background
    // This catches when user returns from Android accessibility/overlay settings
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _xReplyInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    final overlayGranted = await _platform.checkOverlayPermission();
    final accessibilityEnabled = await _platform.checkAccessibilityPermission();

    if (mounted) {
      setState(() {
        _overlayPermissionGranted = overlayGranted;
        _accessibilityEnabled = accessibilityEnabled;
      });
    }
  }

  Future<void> _loadSettings() async {
    _sourceLang = _storage.getSourceLanguage();
    _targetLang = _storage.getTargetLanguage();
    _autoDetect = _storage.getAutoDetect();
    _floatingActionType = _storage.getFloatingActionType();
    _xReplyTone = _storage.getXReplyTone();
    _xReplyLength = _storage.getXReplyLength();
    _xReplyCount = _storage.getXReplyCount();
    _xReplyIncludeEmojis = _storage.getXReplyIncludeEmojis();
    _xReplyInstructionsController.text = _storage.getXReplyInstructions();
    _apiKey = await _storage.getApiKey();

    // Check permissions
    _overlayPermissionGranted = await _platform.checkOverlayPermission();
    _accessibilityEnabled = await _platform.checkAccessibilityPermission();

    if (mounted) setState(() {});
  }

  Future<void> _toggleOverlay(bool value) async {
    if (value) {
      final started = await _platform.startOverlayService();
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Grant overlay permission to turn on the floating assistant.'),
          ),
        );
      }
      setState(() => _overlayServiceRunning = started);
    } else {
      await _platform.stopOverlayService();
      setState(() => _overlayServiceRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.pageBackground,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      const SizedBox(height: 12),
                      ApiKeyInput(
                        initialApiKey: _apiKey,
                        onApiKeySaved: (apiKey) async {
                          await _storage.saveApiKey(apiKey);
                          _openai.setApiKey(apiKey);
                          setState(() => _apiKey = apiKey);
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildOneTapSettings(),
                      const SizedBox(height: 24),
                      _buildLanguageSettings(),
                      const SizedBox(height: 24),
                      _buildGrammarCheckSection(),
                      const SizedBox(height: 24),
                      _buildXReplySettings(),
                      const SizedBox(height: 24),
                      _buildAboutSection(),
                      SizedBox(height: paddingBottom + 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOneTapSettings() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            headline: 'One-Tap Translation',
            subtitle: 'Configure the floating assistant settings.',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Android',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Permission Status
          _buildPermissionStatus(
            title: 'Overlay Permission',
            subtitle: 'Required to show the floating bubble',
            isEnabled: _overlayPermissionGranted,
            icon: Icons.layers_outlined,
            onRequest: () async {
              await _platform.requestOverlayPermission();
              await Future.delayed(const Duration(milliseconds: 500));
              final granted = await _platform.checkOverlayPermission();
              setState(() => _overlayPermissionGranted = granted);
            },
          ),
          const SizedBox(height: 12),
          _buildPermissionStatus(
            title: 'Accessibility Service',
            subtitle: 'Required for auto text detection',
            isEnabled: _accessibilityEnabled,
            icon: Icons.accessibility_new,
            onRequest: () async {
              await _platform.requestAccessibilityPermission();
            },
          ),

          const SizedBox(height: 18),
          _buildSwitchRow(
            title: 'Floating bubble active',
            subtitle: 'Toggle the floating assistant on your home screen.',
            value: _overlayServiceRunning,
            onChanged: _toggleOverlay,
          ),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gesture, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'One-Tap Action',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose what happens when you tap the floating button.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                _buildSegmentedControl(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatus({
    required String title,
    required String subtitle,
    required bool isEnabled,
    required IconData icon,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppColors.success.withOpacity(0.08)
            : AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? AppColors.success.withOpacity(0.3)
              : AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isEnabled ? AppColors.success : AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (isEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Enabled',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            TextButton(
              onPressed: onRequest,
              child: const Text('Enable'),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageSettings() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            headline: 'Default Languages',
            subtitle: 'Defaults used when the app launches.',
          ),
          const SizedBox(height: 18),
          LanguagePicker(
            label: 'Source language',
            selectedLanguage: _sourceLang,
            onLanguageSelected: (lang) async {
              await _storage.saveSourceLanguage(lang);
              setState(() => _sourceLang = lang);
            },
          ),
          const SizedBox(height: 12),
          LanguagePicker(
            label: 'Target language',
            selectedLanguage: _targetLang,
            onLanguageSelected: (lang) async {
              await _storage.saveTargetLanguage(lang);
              setState(() => _targetLang = lang);
            },
          ),
          const SizedBox(height: 12),
          _buildSwitchRow(
            title: 'Auto-detect source language',
            subtitle: 'We\'ll guess the typing language before translating',
            value: _autoDetect,
            onChanged: (value) async {
              await _storage.saveAutoDetect(value);
              setState(() => _autoDetect = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGrammarCheckSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            headline: 'Grammar Check',
            subtitle: 'Check and correct grammar in your text.',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.spellcheck,
                        color: AppColors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proofread Your Text',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fix grammar, spelling, and improve tone',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tip: Set One-Tap Action to "Grammar" above to proofread with one tap from the floating bubble!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXReplySettings() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            headline: 'X Reply Suggestions',
            subtitle:
                'Customize replies generated from a screenshot of a post.',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _xReplyTone,
            decoration: const InputDecoration(
              labelText: 'Reply tone',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Warm', child: Text('Warm')),
              DropdownMenuItem(value: 'Smart', child: Text('Smart')),
              DropdownMenuItem(value: 'Funny', child: Text('Funny')),
              DropdownMenuItem(
                  value: 'Professional', child: Text('Professional')),
              DropdownMenuItem(value: 'Contrarian', child: Text('Contrarian')),
              DropdownMenuItem(value: 'Supportive', child: Text('Supportive')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await _storage.saveXReplyTone(value);
              setState(() => _xReplyTone = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _xReplyLength,
            decoration: const InputDecoration(
              labelText: 'Reply length',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Very short', child: Text('Very short')),
              DropdownMenuItem(value: 'Short', child: Text('Short')),
              DropdownMenuItem(value: 'Medium', child: Text('Medium')),
              DropdownMenuItem(value: 'Detailed', child: Text('Detailed')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await _storage.saveXReplyLength(value);
              setState(() => _xReplyLength = value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reply options: $_xReplyCount',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              SizedBox(
                width: 172,
                child: Slider(
                  min: 1,
                  max: 6,
                  divisions: 5,
                  value: _xReplyCount.toDouble(),
                  label: _xReplyCount.toString(),
                  onChanged: (value) async {
                    final count = value.round();
                    await _storage.saveXReplyCount(count);
                    setState(() => _xReplyCount = count);
                  },
                ),
              ),
            ],
          ),
          _buildSwitchRow(
            title: 'Allow emojis',
            subtitle: 'Use emojis only when they fit the reply style.',
            value: _xReplyIncludeEmojis,
            onChanged: (value) async {
              await _storage.saveXReplyIncludeEmojis(value);
              setState(() => _xReplyIncludeEmojis = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _xReplyInstructionsController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Custom style instructions',
              hintText: 'Example: sound concise, curious, and never salesy',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _storage.saveXReplyInstructions(value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Set One-Tap Action to "X Replies", open a post on X, then tap the bubble. Bhasha captures the visible screen and shows copyable reply options.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            headline: 'About',
            subtitle: 'App information & data controls.',
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
            trailing: const Icon(Icons.info_outline_rounded),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever_outlined,
                color: AppColors.accent),
            title: const Text('Clear all data'),
            subtitle: const Text(
                'Remove API keys, language choices, and preferences.'),
            onTap: _confirmClearData,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildActionOption(
            actionType: 'translate',
            label: 'Translate',
            icon: Icons.translate,
            gradient: AppGradients.primaryButton,
          ),
          _buildActionOption(
            actionType: 'grammar',
            label: 'Grammar',
            icon: Icons.check_circle,
            gradient: AppGradients.successCard,
          ),
          _buildActionOption(
            actionType: 'x_replies',
            label: 'X Replies',
            icon: Icons.chat_bubble_outline_rounded,
            gradient: AppGradients.primaryButton,
          ),
        ],
      ),
    );
  }

  Widget _buildActionOption({
    required String actionType,
    required String label,
    required IconData icon,
    required Gradient gradient,
  }) {
    final isSelected = _floatingActionType == actionType;
    return GestureDetector(
      onTap: () async {
        setState(() => _floatingActionType = actionType);
        await _storage.saveFloatingActionType(actionType);
        await _platform.updateFloatingActionType(actionType);
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 128),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all Bhasha data?'),
        content: const Text(
          'This removes your API key, language selections, and saved preferences.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _storage.clearAll();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All settings cleared.')),
                );
                _loadSettings();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
