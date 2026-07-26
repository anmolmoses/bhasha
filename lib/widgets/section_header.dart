import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String headline;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.headline,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final title = Text(
      headline,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
    );

    final sub = subtitle != null
        ? Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          )
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (sub != null) sub,
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
