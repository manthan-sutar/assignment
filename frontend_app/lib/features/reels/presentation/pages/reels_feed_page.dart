import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/reels_bloc.dart';
import '../bloc/reels_event.dart';
import '../bloc/reels_state.dart';
import '../controllers/reels_audio_controller.dart';
import '../widgets/reel_card.dart';
import '../../domain/entities/reel_entity.dart';

/// Full-screen vertical feed of audio reels (Instagram-style).
/// UI is passive: only reports page index to [ReelsAudioController] and
/// listens to controller state. No audio logic in build().
class ReelsFeedPage extends StatefulWidget {
  const ReelsFeedPage({super.key});

  @override
  State<ReelsFeedPage> createState() => _ReelsFeedPageState();
}

class _ReelsFeedPageState extends State<ReelsFeedPage>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  late final ReelsAudioController _audioController;
  List<ReelEntity> _reels = [];
  bool _hasTriggeredFirstPlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(viewportFraction: 1.0);
    _audioController = ReelsAudioController(onError: _showAudioError);
    _audioController.attach();
    context.read<ReelsBloc>().add(const ReelsLoadRequested());
  }

  void _showAudioError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Could not play audio: $error')),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      _audioController.pause();
    } else if (lifecycle == AppLifecycleState.resumed) {
      _audioController.resume();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _audioController.dispose();
    super.dispose();
  }

  /// Called only when a reel is fully visible (snap): from onPageChanged or
  /// once when feed first loads. Ensures we don't replay on rebuild.
  void _onReelBecameVisible(int index) {
    if (_reels.isEmpty) return;
    _audioController.setReels(_reels);
    _audioController.playReelAt(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: BlocConsumer<ReelsBloc, ReelsState>(
        listener: (context, state) {
          if (state is ReelsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    context.read<ReelsBloc>().add(const ReelsLoadRequested());
                  },
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ReelsLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
                strokeWidth: 2.5,
              ),
            );
          }

          if (state is ReelsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<ReelsBloc>().add(
                          const ReelsLoadRequested(),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is ReelsLoaded) {
            final reels = state.reels;
            if (reels.isEmpty) {
              return Center(
                child: Text(
                  'No reels yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade400),
                ),
              );
            }

            _reels = reels;

            if (!_hasTriggeredFirstPlay) {
              _hasTriggeredFirstPlay = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _onReelBecameVisible(0);
              });
            }

            // Vertical carousel: one full-screen page per reel, snap like Instagram.
            return PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
              onPageChanged: (index) {
                _onReelBecameVisible(index);
              },
              itemCount: reels.length,
              itemBuilder: (context, index) {
                final reel = reels[index];
                return SizedBox.expand(child: ReelCard(reel: reel));
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
