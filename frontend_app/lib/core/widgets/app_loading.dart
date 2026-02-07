import 'package:flutter/material.dart';

/// Consistent loading indicators across the app.
/// Use for section/full-screen loaders so alignment and spacing stay uniform.
class AppLoading {
  AppLoading._();

  /// Default stroke width for all loaders.
  static const double strokeWidth = 2.5;

  /// Vertical padding for section loaders (e.g. lists, "Find people").
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    vertical: 28,
    horizontal: 24,
  );

  /// Spacing between a loader and a label text below it.
  static const double labelSpacing = 14;

  /// Section loader: centered, theme-aware, with consistent padding.
  /// Use in dashboard, live hub, etc. when a section is loading.
  static Widget section(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: sectionPadding,
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Full-screen style loader (e.g. reels feed initial load).
  /// Centered with breathing room.
  static Widget fullScreen(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Loader with a label below (e.g. "Joining call…", "Connecting…").
  /// Centered column with consistent spacing.
  static Widget withLabel(
    BuildContext context, {
    required String label,
    EdgeInsets? padding,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: strokeWidth,
                color: color,
              ),
            ),
            const SizedBox(height: labelSpacing),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline button-sized loader (white for dark buttons).
  static Widget buttonLoader({Color? color}) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? Colors.white),
      ),
    );
  }
}
