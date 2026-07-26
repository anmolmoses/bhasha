import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Status of the One-Tap Action feature
class OneTapStatus {
  final bool overlayPermissionGranted;
  final bool accessibilityEnabled;
  final bool bubbleActive;

  const OneTapStatus({
    required this.overlayPermissionGranted,
    required this.accessibilityEnabled,
    required this.bubbleActive,
  });

  bool get isFullyEnabled =>
      overlayPermissionGranted && accessibilityEnabled && bubbleActive;

  bool get needsSetup => !overlayPermissionGranted || !accessibilityEnabled;
}

/// Hero section for the One-Tap Action feature - the main CTA of the app
class OneTapHero extends StatelessWidget {
  final OneTapStatus status;
  final VoidCallback onEnablePressed;
  final VoidCallback onToggleBubble;
  final VoidCallback onSettingsPressed;
  final bool isLoading;

  const OneTapHero({
    super.key,
    required this.status,
    required this.onEnablePressed,
    required this.onToggleBubble,
    required this.onSettingsPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _getBackgroundGradient(),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: status.isFullyEnabled
                ? AppColors.success.withOpacity(0.3)
                : AppColors.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildDescription(context),
            const SizedBox(height: 24),
            _buildMainCTA(context),
            const SizedBox(height: 20),
            _buildStatusIndicators(context),
          ],
        ),
      ),
    );
  }

  LinearGradient _getBackgroundGradient() {
    if (status.isFullyEnabled) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2DD4A7),
          Color(0xFF47D5B1),
          Color(0xFF5CE1C6),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF5661F6),
        Color(0xFF6C4CFD),
        Color(0xFF8B5CF6),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            status.isFullyEnabled ? Icons.check_circle : Icons.touch_app,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One-Tap Translation',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                status.isFullyEnabled
                    ? 'Active & Ready'
                    : 'Quick Setup Required',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettingsPressed,
          icon: const Icon(Icons.settings_outlined),
          color: Colors.white.withOpacity(0.9),
          tooltip: 'Advanced Settings',
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(0.9),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'In any app: tap the bubble to translate what you typed, or '
              'hold it and speak — your words land in the message box in the '
              'language you picked.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCTA(BuildContext context) {
    final String buttonLabel;
    final IconData buttonIcon;
    final VoidCallback? onPressed;

    if (isLoading) {
      buttonLabel = 'Setting up...';
      buttonIcon = Icons.hourglass_empty;
      onPressed = null;
    } else if (status.isFullyEnabled) {
      buttonLabel = 'Disable Bubble';
      buttonIcon = Icons.pause_circle_outline;
      onPressed = onToggleBubble;
    } else if (status.needsSetup) {
      buttonLabel = 'Enable One-Tap Action';
      buttonIcon = Icons.bolt;
      onPressed = onEnablePressed;
    } else {
      buttonLabel = 'Activate Bubble';
      buttonIcon = Icons.play_circle_outline;
      onPressed = onToggleBubble;
    }

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: status.isFullyEnabled
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  )
                else
                  Icon(
                    buttonIcon,
                    color: status.isFullyEnabled
                        ? AppColors.success
                        : AppColors.primary,
                    size: 24,
                  ),
                const SizedBox(width: 12),
                Text(
                  buttonLabel,
                  style: TextStyle(
                    color: status.isFullyEnabled
                        ? AppColors.success
                        : AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicators(BuildContext context) {
    return Column(
      children: [
        _buildStatusRow(
          context,
          icon: Icons.layers_outlined,
          label: 'Overlay permission',
          isEnabled: status.overlayPermissionGranted,
        ),
        const SizedBox(height: 10),
        _buildStatusRow(
          context,
          icon: Icons.accessibility_new,
          label: 'Accessibility service',
          isEnabled: status.accessibilityEnabled,
        ),
        const SizedBox(height: 10),
        _buildStatusRow(
          context,
          icon: Icons.bubble_chart,
          label: 'Floating bubble',
          isEnabled: status.bubbleActive,
        ),
      ],
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isEnabled,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isEnabled ? 0.25 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white.withOpacity(isEnabled ? 1.0 : 0.5),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(isEnabled ? 0.95 : 0.6),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isEnabled ? 0.25 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
                color: Colors.white.withOpacity(isEnabled ? 1.0 : 0.5),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                isEnabled ? 'Ready' : 'Off',
                style: TextStyle(
                  color: Colors.white.withOpacity(isEnabled ? 1.0 : 0.5),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
