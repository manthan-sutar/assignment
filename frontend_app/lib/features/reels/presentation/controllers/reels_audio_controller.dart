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

/// Reels audio: two [AudioPlayer]s so the next reel is preloaded and starts instantly.
/// Generation token prevents stale setUrl/play.
class ReelsAudioController {
  ReelsAudioController({ReelsAudioErrorCallback? onError}) : _onError = onError;

  final ReelsAudioErrorCallback? _onError;

  List<ReelEntity> _reels = const [];
  final AudioPlayer _playerA = AudioPlayer();
  final AudioPlayer _playerB = AudioPlayer();

  /// True when A is the active (playing) player, B is preload; false when B is active, A is preload.
  bool _mainIsA = true;

  AudioPlayer get _mainPlayer => _mainIsA ? _playerA : _playerB;
  AudioPlayer get _preloadPlayer => _mainIsA ? _playerB : _playerA;

  int _currentReelIndex = -1;

  /// Index loaded in _preloadPlayer (-1 if none).
  int _preloadedIndex = -1;
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

  /// Load a reel so [playReelAt] can start instantly; preloads next reel for instant switch.
  Future<void> prepareReelAt(int index) async {
    if (_disposed || index < 0 || index >= _reels.length) return;
    try {
      await _mainPlayer.setUrl(_reels[index].audioUrl);
      if (_disposed) return;
      _currentReelIndex = index;
      state.value = state.value.copyWith(currentIndex: index);
      _lastPosition = Duration.zero;
      _lastDuration = null;
      _emitPositionDuration();
      _preloadedIndex = -1;
      final next = index + 1;
      if (next < _reels.length) {
        _preloadPlayer
            .setUrl(_reels[next].audioUrl)
            .then((_) {
              if (!_disposed) _preloadedIndex = next;
            })
            .catchError((e) {
              if (!_isIgnorableAudioException(e))
                debugPrint('ReelsAudioController preload error: $e');
            });
      }
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
      debugPrint('ReelsAudioController prepareReelAt error: $e');
    }
  }

  Future<void> playReelAt(int index) async {
    if (_disposed || index < 0 || index >= _reels.length) return;

    final gen = ++_generation;

    if (index == _currentReelIndex) {
      state.value = state.value.copyWith(currentIndex: index);
      _emitPositionDuration();
      if (state.value.isPlaying) return;
      await _resume(gen);
      return;
    }

    // Next reel was preloaded: stop old main, swap roles, play new main instantly (Instagram-like cut).
    if (index == _preloadedIndex) {
      _preloadedIndex = -1;
      _currentReelIndex = index;
      state.value = state.value.copyWith(currentIndex: index);
      _lastPosition = Duration.zero;
      _lastDuration = null;
      _emitPositionDuration();
      _unsubscribe();
      final previousMain = _mainPlayer;
      _mainIsA = !_mainIsA;
      await previousMain
          .stop(); // stop previous reel so we never hear it on the new reel (instant cut)
      if (gen != _generation || _disposed) return;
      _subscribeTo(_mainPlayer);
      try {
        await _mainPlayer.play();
        if (gen != _generation || _disposed) return;
        state.value = state.value.copyWith(isPlaying: true);
      } catch (e) {
        if (_isIgnorableAudioException(e)) return;
        if (gen == _generation) _onError?.call(e);
      }
      final next = index + 1;
      if (next < _reels.length) {
        _preloadPlayer
            .setUrl(_reels[next].audioUrl)
            .then((_) {
              if (!_disposed) _preloadedIndex = next;
            })
            .catchError((_) {});
      }
      return;
    }

    // Load and play on main; preload next. Stop current so we never hear wrong reel.
    final url = _reels[index].audioUrl;
    try {
      if (gen != _generation) return;
      await _mainPlayer.stop();
      if (gen != _generation || _disposed) return;
      await _mainPlayer.setUrl(url);
      if (gen != _generation || _disposed) return;
      _currentReelIndex = index;
      _preloadedIndex = -1;
      state.value = state.value.copyWith(currentIndex: index);
      _lastPosition = Duration.zero;
      _lastDuration = null;
      _emitPositionDuration();
      await _mainPlayer.play();
      if (gen != _generation || _disposed) return;
      state.value = state.value.copyWith(isPlaying: true);
      final next = index + 1;
      if (next < _reels.length) {
        _preloadPlayer
            .setUrl(_reels[next].audioUrl)
            .then((_) {
              if (!_disposed) _preloadedIndex = next;
            })
            .catchError((_) {});
      }
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
      if (gen == _generation) _onError?.call(e);
    }
  }

  Future<void> _resume(int gen) async {
    try {
      await _mainPlayer.play();
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
      await _mainPlayer.pause();
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
    }
    state.value = state.value.copyWith(isPlaying: false);
  }

  /// Call when app goes to background so we resume playback when app returns.
  Future<void> pauseForAppBackground() async {
    if (_disposed) return;
    if (_currentReelIndex >= 0) _wasPlayingBeforeAppPause = true;
    try {
      await _mainPlayer.pause();
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
    }
    state.value = state.value.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    if (_disposed || _currentReelIndex < 0 || !_wasPlayingBeforeAppPause)
      return;
    try {
      await _mainPlayer.play();
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
    }
    state.value = state.value.copyWith(isPlaying: true);
  }

  Future<void> togglePlayPause() async {
    if (_disposed || _currentReelIndex < 0) return;
    if (state.value.isPlaying) {
      await _mainPlayer.pause();
      state.value = state.value.copyWith(isPlaying: false);
    } else {
      try {
        await _mainPlayer.play();
        state.value = state.value.copyWith(isPlaying: true);
      } catch (e) {
        if (!_isIgnorableAudioException(e)) _onError?.call(e);
      }
    }
  }

  void _unsubscribe() {
    _playerSub?.cancel();
    _playerSub = null;
    _positionSub?.cancel();
    _positionSub = null;
    _durationSub?.cancel();
    _durationSub = null;
    _stopProgressTimer();
  }

  void _subscribeTo(AudioPlayer player) {
    _unsubscribe();
    _playerSub = player.playerStateStream.listen((s) {
      if (_disposed) return;
      state.value = state.value.copyWith(isPlaying: s.playing);
      if (s.playing) {
        _startProgressTimer();
      } else {
        _stopProgressTimer();
      }
    });
    _positionSub = player.positionStream.listen((p) {
      _lastPosition = p;
      _emitPositionDuration();
    });
    _durationSub = player.durationStream.listen((d) {
      _lastDuration = d;
      _emitPositionDuration();
    });
  }

  void attach() {
    _playerA.setLoopMode(LoopMode.one);
    _playerB.setLoopMode(LoopMode.one);
    _subscribeTo(_mainPlayer);
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed || !_mainPlayer.playing) return;
      _lastPosition = _mainPlayer.position;
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
    _unsubscribe();
    _playerA.dispose();
    _playerB.dispose();
  }
}
