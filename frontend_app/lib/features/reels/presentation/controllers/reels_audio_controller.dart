import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/reel_entity.dart';

/// Callback for playback errors (e.g. to show SnackBar). Not called for cancelled/stale ops.
typedef ReelsAudioErrorCallback = void Function(Object error);

/// State exposed to UI: current reel index and whether audio is playing.
/// Controller is the single source of truth; UI only reflects this.
class ReelsPlaybackState {
  const ReelsPlaybackState({
    required this.currentIndex,
    required this.isPlaying,
  });

  final int currentIndex;
  final bool isPlaying;

  ReelsPlaybackState copyWith({int? currentIndex, bool? isPlaying}) {
    return ReelsPlaybackState(
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

/// Dedicated controller for reels audio: single logical playback, preload next,
/// lifecycle-safe, and decoupled from UI.
///
/// Design decisions:
/// - We use two [AudioPlayer] instances: one for current playback, one to
///   preload the next reel's URL. Only one ever plays at a time. This gives
///   instant start when swiping to next without multiple "playback" players.
/// - Snap-based: UI calls [playReelAt] only when a reel is fully visible
///   (e.g. from PageView.onPageChanged). We avoid replaying when index
///   unchanged (idempotent).
/// - Generation token: each [playReelAt] call increments a token; async work
///   that completes with a stale token is ignored to avoid race conditions
///   when the user scrolls fast.
/// - Preload is best-effort; we don't block UI on preload completion.
class ReelsAudioController {
  ReelsAudioController({ReelsAudioErrorCallback? onError}) : _onError = onError;

  final ReelsAudioErrorCallback? _onError;

  List<ReelEntity> _reels = const [];
  final AudioPlayer _playbackPlayer = AudioPlayer();
  final AudioPlayer _preloadPlayer = AudioPlayer();

  /// Which of the two players is currently playing (0 = playback, 1 = preload).
  /// The other is used to preload the next URL.
  int _activeIndex = 0;
  int _preloadedReelIndex = -1;
  int _currentReelIndex = -1;
  int _generation = 0;
  bool _wasPlayingBeforeAppPause = false;

  StreamSubscription<PlayerState>? _playbackSub;
  StreamSubscription<PlayerState>? _preloadSub;

  final ValueNotifier<ReelsPlaybackState> state = ValueNotifier(
    const ReelsPlaybackState(currentIndex: -1, isPlaying: false),
  );

  bool _disposed = false;

  /// Reels list. Must be set before calling [playReelAt]. Safe to call multiple times.
  void setReels(List<ReelEntity> reels) {
    _reels = reels;
  }

  /// Call when the user has landed on a reel (e.g. from PageView.onPageChanged).
  /// Only one reel plays at a time; previous stops immediately. If [index] is
  /// already current and playing, this is a no-op to avoid replay on rebuild.
  Future<void> playReelAt(int index) async {
    if (_disposed || index < 0 || index >= _reels.length) return;

    final gen = ++_generation;

    if (index == _currentReelIndex) {
      if (state.value.isPlaying) return;
      _resumeCurrentPlayer(gen);
      return;
    }

    await _stopBothPlayers();

    if (gen != _generation) return;

    _currentReelIndex = index;
    state.value = state.value.copyWith(currentIndex: index);

    final reel = _reels[index];

    if (index == _preloadedReelIndex) {
      _activeIndex = 1 - _activeIndex;
      _preloadedReelIndex = -1;
      try {
        await _currentPlayer.play();
        if (gen != _generation) return;
        state.value = state.value.copyWith(isPlaying: true);
      } catch (e) {
        if (gen == _generation) _onError?.call(e);
      }
      _schedulePreload(index + 1, gen);
      return;
    }

    try {
      await _playbackPlayer.setUrl(reel.audioUrl);
      if (gen != _generation) return;
      _activeIndex = 0;
      await _playbackPlayer.play();
      if (gen != _generation) return;
      state.value = state.value.copyWith(isPlaying: true);
    } catch (e) {
      if (gen == _generation) _onError?.call(e);
    }
    _schedulePreload(index + 1, gen);
  }

  AudioPlayer get _currentPlayer =>
      _activeIndex == 0 ? _playbackPlayer : _preloadPlayer;
  AudioPlayer get _idlePlayer =>
      _activeIndex == 0 ? _preloadPlayer : _playbackPlayer;

  Future<void> _resumeCurrentPlayer(int gen) async {
    try {
      await _currentPlayer.play();
      if (gen == _generation && !_disposed) {
        state.value = state.value.copyWith(isPlaying: true);
      }
    } catch (e) {
      if (gen == _generation) _onError?.call(e);
    }
  }

  Future<void> _stopBothPlayers() async {
    await Future.wait([_playbackPlayer.stop(), _preloadPlayer.stop()]);
    _preloadedReelIndex = -1;
    _activeIndex = 0;
    if (!_disposed) {
      state.value = state.value.copyWith(isPlaying: false);
    }
  }

  void _schedulePreload(int nextIndex, int gen) {
    if (nextIndex >= _reels.length) return;
    final url = _reels[nextIndex].audioUrl;
    _idlePlayer
        .setUrl(url)
        .then((_) {
          if (_disposed || gen != _generation) return;
          _preloadedReelIndex = nextIndex;
        })
        .catchError((_) {});
  }

  /// Pause playback (e.g. app to background). Safe to call when already paused.
  Future<void> pause() async {
    if (_disposed) return;
    _wasPlayingBeforeAppPause = state.value.isPlaying;
    await _currentPlayer.pause();
    state.value = state.value.copyWith(isPlaying: false);
  }

  /// Resume playback (e.g. app to foreground). Only resumes if audio was
  /// playing before [pause] (avoids starting playback if user had paused manually).
  Future<void> resume() async {
    if (_disposed || _currentReelIndex < 0 || !_wasPlayingBeforeAppPause)
      return;
    await _currentPlayer.play();
    state.value = state.value.copyWith(isPlaying: true);
  }

  /// Toggle play/pause for the current reel. No-op if no current reel.
  Future<void> togglePlayPause() async {
    if (_disposed || _currentReelIndex < 0) return;
    if (state.value.isPlaying) {
      await _currentPlayer.pause();
      state.value = state.value.copyWith(isPlaying: false);
    } else {
      await _currentPlayer.play();
      state.value = state.value.copyWith(isPlaying: true);
    }
  }

  /// Start listening to player state so [state] stays in sync. Call once after construction.
  void attach() {
    void sync(PlayerState s) {
      if (_disposed) return;
      state.value = state.value.copyWith(isPlaying: s.playing);
    }

    _playbackSub = _playbackPlayer.playerStateStream.listen(sync);
    _preloadSub = _preloadPlayer.playerStateStream.listen(sync);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _playbackSub?.cancel();
    _preloadSub?.cancel();
    _playbackPlayer.dispose();
    _preloadPlayer.dispose();
  }
}
