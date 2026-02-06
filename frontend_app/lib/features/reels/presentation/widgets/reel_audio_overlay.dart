import 'package:flutter/material.dart';

/// Instagram-style progress bar: lighter white track full width, whiter fill for progress.
class ReelProgressBar extends StatelessWidget {
  const ReelProgressBar({
    super.key,
    required this.progress,
    this.height = 3,
    this.trackColor,
    this.fillColor,
  });

  /// Progress 0.0 to 1.0 (how much of the reel is complete).
  final double progress;
  final double height;

  /// Lighter white for the full-width track (default ~40% opacity).
  final Color? trackColor;

  /// Whiter for the progress fill (default ~30% more opaque than track).
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final track = trackColor ?? Colors.white.withOpacity(0.4);
    final fill = fillColor ?? Colors.white.withOpacity(0.95);
    final p = progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: height,
          width: w,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Full-width lighter track (background)
              Positioned.fill(child: Container(color: track)),
              // Whiter fill showing progress (left portion)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: w * p,
                child: Container(color: fill),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Progress bar and banner are now part of ReelCard so the whole card scrolls together.
