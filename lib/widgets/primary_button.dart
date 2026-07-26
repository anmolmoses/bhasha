import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    final buttonChild = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            color: isEnabled ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );

    final button = InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isEnabled ? onPressed : null,
      child: Ink(
        decoration: BoxDecoration(
          gradient: isEnabled
              ? AppGradients.primaryButton
              : LinearGradient(
                  colors: [
                    Colors.grey.shade300,
                    Colors.grey.shade200,
                  ],
                ),
          borderRadius: const BorderRadius.all(Radius.circular(18)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: buttonChild,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
