import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/languages.dart';
import '../models/sarvam_error.dart';
import '../services/platform_service.dart';
import '../services/sarvam_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/one_tap_hero.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_header.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _storage = StorageService();
  final _sarvam = SarvamService.shared;
  final _platform = PlatformService();
  final _inputController = TextEditingController();

  late String _sourceLang;
  late String _targetLang;

  String _result = '';
  bool _isLoading = false;
  bool _isSettingUp = false;

  // One-Tap Status
  bool _overlayPermissionGranted = false;
  bool _accessibilityEnabled = false;
  bool _bubbleActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _checkPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh permissions when app resumes from background
    // This catches when user returns from Android accessibility settings
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _loadSettings() async {
    _sourceLang = _storage.getSourceLanguage();
    _targetLang = _storage.getTargetLanguage();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkPermissions() async {
    final overlayGranted = await _platform.checkOverlayPermission();
    final accessibilityEnabled = await _platform.checkAccessibilityPermission();

    if (mounted) {
      setState(() {
        _overlayPermissionGranted = overlayGranted;
        _accessibilityEnabled = accessibilityEnabled;
        // Bubble is considered active if overlay is running (we'll track this properly)
        _bubbleActive = overlayGranted && accessibilityEnabled;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _enableOneTapAction() async {
    setState(() => _isSettingUp = true);

    try {
      // Step 1: Check and request overlay permission
      if (!_overlayPermissionGranted) {
        await _platform.requestOverlayPermission();
        // Wait a moment for permission to be granted
        await Future.delayed(const Duration(milliseconds: 500));
        final overlayGranted = await _platform.checkOverlayPermission();
        if (!overlayGranted) {
          _showMessage('Please grant overlay permission to continue');
          setState(() => _isSettingUp = false);
          return;
        }
        setState(() => _overlayPermissionGranted = true);
      }

      // Step 2: Check and request accessibility permission
      if (!_accessibilityEnabled) {
        await _platform.requestAccessibilityPermission();
        _showMessage('Enable Bhasha in Accessibility Settings');
        setState(() => _isSettingUp = false);
        return;
      }

      // Step 3: Ask for the microphone, used by hold-to-speak.
      // Deliberately not a gate: tap-to-translate works without it, so a parent
      // who declines still gets a working bubble.
      if (!await _platform.checkMicPermission()) {
        await _platform.requestMicPermission();
      }

      // Step 4: Start the overlay service
      final started = await _platform.startOverlayService();
      if (started) {
        setState(() => _bubbleActive = true);
        _showSuccess('One-Tap Translation activated! 🎉');
      } else {
        _showMessage('Could not start the floating bubble');
      }
    } catch (e) {
      _showMessage('Setup error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSettingUp = false);
      }
    }
  }

  Future<void> _toggleBubble() async {
    if (_bubbleActive) {
      await _platform.stopOverlayService();
      setState(() => _bubbleActive = false);
      _showMessage('Floating bubble disabled');
    } else {
      final started = await _platform.startOverlayService();
      if (started) {
        setState(() => _bubbleActive = true);
        _showSuccess('Floating bubble activated!');
      } else {
        _showMessage('Could not start the floating bubble');
      }
    }
  }

  Future<void> _translate() async {
    if (_inputController.text.trim().isEmpty) {
      _showMessage('Please enter text to translate');
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
    });

    final sourceCode = Languages.codeFor(_sourceLang) ?? 'auto';
    final targetCode = Languages.codeFor(_targetLang);
    if (targetCode == null) {
      setState(() => _isLoading = false);
      _showMessage('$_targetLang is not supported. Pick another language.');
      return;
    }

    try {
      final translated = await _sarvam.translate(
        input: _inputController.text,
        sourceLanguageCode: sourceCode,
        targetLanguageCode: targetCode,
      );
      setState(() {
        _result = translated;
        _isLoading = false;
      });
    } on SarvamException catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage(e.parentMessage);
    }
  }

  void _copyToClipboard() {
    if (_result.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _result));
    _showSuccess('Copied to clipboard');
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
    });
    _storage.saveSourceLanguage(_sourceLang);
    _storage.saveTargetLanguage(_targetLang);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      _showMessage('Clipboard is empty');
      return;
    }
    setState(() {
      _inputController
        ..text = text.trim()
        ..selection = TextSelection.collapsed(
          offset: _inputController.text.length,
        );
    });
  }

  void _clearWorkspace() {
    setState(() {
      _inputController.clear();
      _result = '';
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _loadSettings();
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.pageBackground,
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                sliver: SliverToBoxAdapter(child: _buildTopBar()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverToBoxAdapter(child: _buildOneTapHero()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverToBoxAdapter(child: _buildLanguageSelector()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverToBoxAdapter(child: _buildTranslationWorkspace()),
              ),
              if (_isLoading)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_result.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  sliver: SliverToBoxAdapter(child: _buildResultCard()),
                ),
              SliverPadding(
                padding: EdgeInsets.only(bottom: paddingBottom + 24),
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bhasha',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Translate instantly across any app',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: _openSettings,
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildOneTapHero() {
    return OneTapHero(
      status: OneTapStatus(
        overlayPermissionGranted: _overlayPermissionGranted,
        accessibilityEnabled: _accessibilityEnabled,
        bubbleActive: _bubbleActive,
      ),
      onEnablePressed: _enableOneTapAction,
      onToggleBubble: _toggleBubble,
      onSettingsPressed: _openSettings,
      isLoading: _isSettingUp,
    );
  }

  Widget _buildLanguageSelector() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            headline: 'Translation Languages',
            subtitle: 'Choose your source and target languages',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildLanguageTile(
                  label: 'From',
                  value: _sourceLang,
                  onTap: () => _showLanguageSheet(isSource: true),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _swapLanguages,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  color: AppColors.primary,
                  tooltip: 'Swap languages',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLanguageTile(
                  label: 'To',
                  value: _targetLang,
                  onTap: () => _showLanguageSheet(isSource: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1.1,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationWorkspace() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            headline: 'Manual Translation',
            subtitle: 'Or translate text directly in the app',
            trailing: TextButton(
              onPressed: _clearWorkspace,
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inputController,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Type or paste text here...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Translate',
                  icon: Icons.translate,
                  onPressed: _isLoading ? null : _translate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Paste'),
                avatar: const Icon(Icons.paste_rounded, size: 18),
                onPressed: _pasteFromClipboard,
              ),
              if (_result.isNotEmpty)
                ActionChip(
                  label: const Text('Copy result'),
                  avatar: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: _copyToClipboard,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5661F6), Color(0xFF7A4CFF)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(Icons.translate_rounded, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Translation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
                tooltip: 'Copy result',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            _result,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguageSheet({required bool isSource}) async {
    final controller = TextEditingController();
    final allLanguages = Languages.supported;
    List<String> filtered = List.from(allLanguages);

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select ${isSource ? 'source' : 'target'} language',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Search language…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        filtered = allLanguages
                            .where((lang) => lang
                                .toLowerCase()
                                .contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No matches found',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          )
                        : ListView.separated(
                            itemBuilder: (_, index) {
                              final language = filtered[index];
                              final isSelected = isSource
                                  ? language == _sourceLang
                                  : language == _targetLang;
                              return ListTile(
                                title: Text(language),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.primary)
                                    : null,
                                onTap: () => Navigator.pop(context, language),
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemCount: filtered.length,
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    controller.dispose();

    if (selected != null) {
      setState(() {
        if (isSource) {
          _sourceLang = selected;
          _storage.saveSourceLanguage(selected);
        } else {
          _targetLang = selected;
          _storage.saveTargetLanguage(selected);
        }
      });
    }
  }
}
