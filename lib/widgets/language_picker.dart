import 'package:flutter/material.dart';

import '../constants/languages.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class LanguagePicker extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;
  final String label;

  const LanguagePicker({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showLanguageSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                      selectedLanguage,
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
      ),
    );
  }

  Future<void> _showLanguageSheet(BuildContext context) async {
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
                    'Select $label',
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          )
                        : ListView.separated(
                            itemBuilder: (_, index) {
                              final language = filtered[index];
                              final isSelected = language == selectedLanguage;
                              return ListTile(
                                title: Text(language),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.primary)
                                    : null,
                                onTap: () => Navigator.pop(context, language),
                              );
                            },
                            separatorBuilder: (_, __) => const Divider(height: 1),
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
      onLanguageSelected(selected);
    }
  }
}
