import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/reel_entity.dart';

/// Callback for playback errors (e.g. to show SnackBar). Not called for cancelled/stale ops.
typedef ReelsAudioErrorCallback = void Function(Object error);

/// State exposed to UI: current reel index and whether audio is playing.
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

/// Returns true if the exception should be ignored (user swiped / load cancelled).
bool _isIgnorableAudioException(Object e) {
  if (e is PlatformException) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    if (code == 'abort' || msg.contains('loading interrupted')) return true;
    if (msg.contains('already exists')) return true;
  }
  return false;
}

/// Reels audio: single [AudioPlayer]. Generation token prevents stale setUrl/play.
/// First reel is prepared so it plays immediately; switching reels does stop → setUrl → play.
class ReelsAudioController {
  ReelsAudioController({ReelsAudioErrorCallback? onError}) : _onError = onError;

  final ReelsAudioErrorCallback? _onError;

  List<ReelEntity> _reels = const [];
  final AudioPlayer _player = AudioPlayer();

  int _currentReelIndex = -1;
  int _preparedReelIndex = -1;
  int _generation = 0;
  bool _wasPlayingBeforeAppPause = false;
  StreamSubscription<PlayerState>? _playerSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  Timer? _progressTimer;
  Duration _lastPosition = Duration.zero;
  Duration? _lastDuration;

  final ValueNotifier<ReelsPlaybackState> state = ValueNotifier(
    const ReelsPlaybackState(currentIndex: -1, isPlaying: false),
  );

  /// Current position and duration for the playing reel (for progress bar).
  final ValueNotifier<({Duration position, Duration? duration})>
  positionDuration = ValueNotifier((position: Duration.zero, duration: null));

  bool _disposed = false;

  void _emitPositionDuration() {
    if (_disposed) return;
    positionDuration.value = (position: _lastPosition, duration: _lastDuration);
  }

  void setReels(List<ReelEntity> reels) {
    _reels = reels;
  }

  /// Load a reel so [playReelAt] can start instantly. Returns when ready or fails.
  Future<void> prepareReelAt(int index) async {
    if (_disposed || index < 0 || index >= _reels.length) return;
    try {
      await _player.setUrl(_reels[index].audioUrl);
      if (_disposed) return;
      _preparedReelIndex = index;
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
      debugPrint('ReelsAudioController prepareReelAt error: $e');
    }
  }

  Future<void> playReelAt(int index) async {
    if (_disposed || index < 0 || index >= _reels.length) return;

    final gen = ++_generation;

    if (index == _currentReelIndex) {
      if (state.value.isPlaying) return;
      await _resume(gen);
      return;
    }

    if (index == _preparedReelIndex) {
      _preparedReelIndex = -1;
      _currentReelIndex = index;
      state.value = state.value.copyWith(currentIndex: index);
      _lastPosition = Duration.zero;
      _emitPositionDuration();
      try {
        await _player.play();
        if (gen != _generation || _disposed) return;
        state.value = state.value.copyWith(isPlaying: true);
      } catch (e) {
        if (_isIgnorableAudioException(e)) return;
        if (gen == _generation) _onError?.call(e);
      }
      return;
    }

    // Don't call stop() before setUrl - setUrl replaces the source and avoids
    // leaving the player in a bad state on some platforms.
    final url = _reels[index].audioUrl;
    try {
      if (gen != _generation) return;
      await _player.setUrl(url);
      if (gen != _generation || _disposed) return;
      _currentReelIndex = index;
      state.value = state.value.copyWith(currentIndex: index);
      _lastPosition = Duration.zero;
      _lastDuration = null;
      _emitPositionDuration();
      await _player.play();
      if (gen != _generation || _disposed) return;
      state.value = state.value.copyWith(isPlaying: true);
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
      if (gen == _generation) _onError?.call(e);
    }
  }

  Future<void> _resume(int gen) async {
    try {
      await _player.play();
      if (gen == _generation && !_disposed) {
        state.value = state.value.copyWith(isPlaying: true);
      }
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
      if (gen == _generation) _onError?.call(e);
    }
  }

  Future<void> pause() async {
    if (_disposed) return;
    _wasPlayingBeforeAppPause = state.value.isPlaying;
    try {
      await _player.pause();
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
    }
    state.value = state.value.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    if (_disposed || _currentReelIndex < 0 || !_wasPlayingBeforeAppPause)
      return;
    try {
      await _player.play();
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
    }
    state.value = state.value.copyWith(isPlaying: true);
  }

  Future<void> togglePlayPause() async {
    if (_disposed || _currentReelIndex < 0) return;
    if (state.value.isPlaying) {
      await _player.pause();
      state.value = state.value.copyWith(isPlaying: false);
    } else {
      try {
        await _player.play();
        state.value = state.value.copyWith(isPlaying: true);
      } catch (e) {
        if (!_isIgnorableAudioException(e)) _onError?.call(e);
      }
    }
  }

  void attach() {
    _playerSub = _player.playerStateStream.listen((s) {
      if (_disposed) return;
      state.value = state.value.copyWith(isPlaying: s.playing);
      if (s.playing) {
        _startProgressTimer();
      } else {
        _stopProgressTimer();
      }
    });
    _positionSub = _player.positionStream.listen((p) {
      _lastPosition = p;
      _emitPositionDuration();
    });
    _durationSub = _player.durationStream.listen((d) {
      _lastDuration = d;
      _emitPositionDuration();
    });
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed || !_player.playing) return;
      _lastPosition = _player.position;
      _emitPositionDuration();
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _stopProgressTimer();
    _playerSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
  }
}
