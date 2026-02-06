import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../domain/entities/reel_entity.dart';
import '../controllers/reels_audio_controller.dart';
import 'reel_audio_overlay.dart';

/// Single full-screen reel: image, gradient, and bottom banner (progress + title).
/// Banner is part of the card so the whole thing scrolls together.
class ReelCard extends StatelessWidget {
  const ReelCard({
    super.key,
    required this.reel,
    required this.index,
    required this.controller,
  });

  final ReelEntity reel;
  final int index;
  final ReelsAudioController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: reel.imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (_, __, dynamic error) => Container(
            color: Colors.grey.shade800,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Image unavailable',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.2), Colors.transparent],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _ReelCardBanner(
            reel: reel,
            index: index,
            controller: controller,
          ),
        ),
      ],
    );
  }
}

/// Bottom banner (progress + title) for one reel card. Progress animates only when this card is current.
class _ReelCardBanner extends StatelessWidget {
  const _ReelCardBanner({
    required this.reel,
    required this.index,
    required this.controller,
  });

  final ReelEntity reel;
  final int index;
  final ReelsAudioController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReelsPlaybackState>(
      valueListenable: controller.state,
      builder: (_, state, __) {
        final isCurrent = state.currentIndex == index && index >= 0;
        return ValueListenableBuilder<
          ({Duration position, Duration? duration})
        >(
          valueListenable: controller.positionDuration,
          builder: (_, pd, __) {
            final durationMs = pd.duration?.inMilliseconds ?? 0;
            final totalMs = durationMs > 0
                ? durationMs
                : (reel.durationSeconds * 1000);
            final progress = isCurrent && totalMs > 0
                ? (pd.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
                : 0.0;
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 3,
                      width: double.infinity,
                      child: ReelProgressBar(progress: progress, height: 3),
                    ),
                    if (reel.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Text(
                          reel.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
