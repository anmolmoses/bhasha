import 'package:flutter/material.dart';

import '../constants/languages.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_header.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _apiKeyController = TextEditingController();

  final _storage = StorageService();

  int _currentPage = 0;
  String _sourceLang = 'Kannada';
  String _targetLang = 'English';
  bool _obscureApiKey = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please paste your Sarvam API key to continue.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final apiKey = _apiKeyController.text.trim();
    await _storage.saveSarvamApiKey(apiKey);
    await _storage.saveSourceLanguage(_sourceLang);
    await _storage.saveTargetLanguage(_targetLang);
    await _storage.setFirstTimeSetupComplete();

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
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
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      'Get set up',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProgressDots()),
                    if (_currentPage < 2)
                      TextButton(
                        onPressed: () => _pageController.jumpToPage(2),
                        child: const Text('Skip'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildWelcomePage(),
                    _buildLanguagePage(),
                    _buildApiKeyPage(),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + paddingBottom),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: _previousPage,
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox(width: 64),
                    const Spacer(),
                    PrimaryButton(
                      label: _currentPage == 2 ? 'Start exploring' : 'Next',
                      icon: _currentPage == 2
                          ? Icons.rocket_launch
                          : Icons.arrow_forward_rounded,
                      expand: false,
                      onPressed: _isSaving ? null : _nextPage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: _currentPage == index ? 26 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 160,
            width: 160,
            decoration: BoxDecoration(
              gradient: AppGradients.primaryButton,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 72,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Bhasha',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Translate across languages, polish grammar, and keep conversations flowing from any app.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GlassCard(
            child: Column(
              children: [
                _buildFeature(
                  icon: Icons.language_rounded,
                  title: 'Instant translations',
                  description:
                      'Swap between source and target languages with a tap and get fluent responses fast.',
                ),
                const Divider(height: 24),
                _buildFeature(
                  icon: Icons.spellcheck,
                  title: 'Confident writing',
                  description:
                      'Fix grammar, spelling, and tone so every sentence sounds natural.',
                ),
                const Divider(height: 24),
                _buildFeature(
                  icon: Icons.bubble_chart_outlined,
                  title: 'Floating assistant',
                  description:
                      'Stay in WhatsApp or any app. Use a modern overlay to proof messages on the fly.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.12),
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguagePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  headline: 'Choose your languages',
                  subtitle:
                      'We’ll use these as your default pair. You can always change them later.',
                ),
                const SizedBox(height: 24),
                _buildLanguageSelectorTile(
                  label: 'Source language',
                  value: _sourceLang,
                  onTap: () => _showLanguageSheet(isSource: true),
                ),
                const SizedBox(height: 16),
                _buildLanguageSelectorTile(
                  label: 'Target language',
                  value: _targetLang,
                  onTap: () => _showLanguageSheet(isSource: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectorTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  headline: 'Secure your Sarvam API key',
                  subtitle:
                      'This stays encrypted on your device. We never send it anywhere else.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: 'API key',
                    hintText: 'sk_...',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureApiKey = !_obscureApiKey;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tip: Visit dashboard.sarvam.ai → API keys → create a subscription key. Paste it above.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
        } else {
          _targetLang = selected;
        }
      });
    }
  }
}
