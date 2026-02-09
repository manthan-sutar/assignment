import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/cache/reel_audio_cache.dart';
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

/// Reels audio: three [AudioPlayer]s — prev, current, next. Current plays; prev/next are
/// preloaded so both forward and backward swipes start instantly.
class ReelsAudioController {
  ReelsAudioController({
    ReelsAudioErrorCallback? onError,
    ReelAudioCache? audioCache,
  })  : _onError = onError,
        _audioCache = audioCache;

  final ReelsAudioErrorCallback? _onError;
  final ReelAudioCache? _audioCache;

  List<ReelEntity> _reels = const [];

  final List<AudioPlayer> _players = [
    AudioPlayer(),
    AudioPlayer(),
    AudioPlayer(),
  ];

  /// Slot indices (0, 1, 2) for prev / current / next. Rotated on swipe.
  int _slotPrev = 0;
  int _slotCurrent = 1;
  int _slotNext = 2;

  AudioPlayer get _playerPrev => _players[_slotPrev];
  AudioPlayer get _playerCurrent => _players[_slotCurrent];
  AudioPlayer get _playerNext => _players[_slotNext];

  int _currentReelIndex = -1;
  int _generation = 0;
  bool _wasPlayingBeforeAppPause = false;

  /// Ensures only one playReelAt runs at a time (prevents two players playing after fast swipes).
  Future<void>? _playReelAtGuard;

  /// During stress scrolling, only the latest requested index is applied; older queued calls skip.
  int? _latestRequestedIndex;

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
      positionDuration =
      ValueNotifier((position: Duration.zero, duration: null));

  bool _disposed = false;

  void _emitPositionDuration() {
    if (_disposed) return;
    positionDuration.value = (position: _lastPosition, duration: _lastDuration);
  }

  void setReels(List<ReelEntity> reels) {
    _reels = reels;
  }

  /// Load current reel and preload prev + next so both directions start instantly.
  /// Uses raw URL so setUrl is immediate; cache prefetches in background for future plays.
  Future<void> prepareReelAt(int index) async {
    if (_disposed || index < 0 || index >= _reels.length) return;
    _audioCache?.prefetchAround(index, _reels);
    try {
      final url = _reels[index].audioUrl;
      if (url.isEmpty || _disposed) return;
      await _playerCurrent.setUrl(url);
      if (_disposed) return;
      _currentReelIndex = index;
      state.value = state.value.copyWith(currentIndex: index);
      _lastPosition = Duration.zero;
      _lastDuration = null;
      _emitPositionDuration();

      // Preload prev/next with raw URL so setUrl runs immediately (no cache lookup delay).
      final prevIndex = index - 1;
      if (prevIndex >= 0) {
        _playerPrev.setUrl(_reels[prevIndex].audioUrl).catchError((e) {
          if (!_isIgnorableAudioException(e))
            debugPrint('ReelsAudioController preload prev error: $e');
          return null;
        });
      }
      final nextIndex = index + 1;
      if (nextIndex < _reels.length) {
        _playerNext.setUrl(_reels[nextIndex].audioUrl).catchError((e) {
          if (!_isIgnorableAudioException(e))
            debugPrint('ReelsAudioController preload next error: $e');
          return null;
        });
      }
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
      debugPrint('ReelsAudioController prepareReelAt error: $e');
    }
  }

  Future<void> playReelAt(int index) async {
    if (_disposed || index < 0 || index >= _reels.length) return;

    _latestRequestedIndex = index;

    final previous = _playReelAtGuard;
    final completer = Completer<void>();
    _playReelAtGuard = completer.future;
    await previous; // wait for any in-flight transition to finish
    if (_disposed) {
      completer.complete();
      return;
    }
    // Stress scroll: a newer playReelAt already requested a different index; skip this one.
    if (_latestRequestedIndex != index) {
      completer.complete();
      return;
    }

    final gen = ++_generation;

    if (index == _currentReelIndex) {
      state.value = state.value.copyWith(currentIndex: index);
      _emitPositionDuration();
      if (state.value.isPlaying) {
        completer.complete();
        return;
      }
      await _resume(gen);
      completer.complete();
      return;
    }

    // Swipe forward: next becomes current, current becomes prev, prev becomes next (load new).
    if (index == _currentReelIndex + 1) {
      _audioCache?.prefetchAround(index, _reels);
      _currentReelIndex = index;
      state.value = state.value.copyWith(currentIndex: index);
      _lastPosition = Duration.zero;
      _lastDuration = null;
      _emitPositionDuration();
      _unsubscribe();
      await _playerCurrent.stop();
      if (gen != _generation || _disposed) {
        completer.complete();
        return;
      }
      _rotateForward();
      _subscribeTo(_playerCurrent);
      try {
        await _playerCurrent.seek(Duration.zero);
        if (gen != _generation || _disposed) {
          completer.complete();
          return;
        }
        await _playerCurrent.play();
        if (gen != _generation || _disposed) {
          completer.complete();
          return;
        }
        state.value = state.value.copyWith(isPlaying: true);
      } catch (e) {
        if (_isIgnorableAudioException(e)) {
          completer.complete();
          return;
        }
        if (gen == _generation) _onError?.call(e);
      }
      final nextIndex = index + 1;
      if (nextIndex < _reels.length) {
        _playerNext.setUrl(_reels[nextIndex].audioUrl).catchError((_) => null);
      }
      completer.complete();
      return;
    }

    // Swipe backward: prev becomes current, current becomes next, next becomes prev (load new).
    if (index == _currentReelIndex - 1) {
      _audioCache?.prefetchAround(index, _reels);
      _currentReelIndex = index;
      state.value = state.value.copyWith(currentIndex: index);
      _lastPosition = Duration.zero;
      _lastDuration = null;
      _emitPositionDuration();
      _unsubscribe();
      await _playerCurrent.stop();
      if (gen != _generation || _disposed) {
        completer.complete();
        return;
      }
      _rotateBackward();
      _subscribeTo(_playerCurrent);
      try {
        await _playerCurrent.seek(Duration.zero);
        if (gen != _generation || _disposed) {
          completer.complete();
          return;
        }
        await _playerCurrent.play();
        if (gen != _generation || _disposed) {
          completer.complete();
          return;
        }
        state.value = state.value.copyWith(isPlaying: true);
      } catch (e) {
        if (_isIgnorableAudioException(e)) {
          completer.complete();
          return;
        }
        if (gen == _generation) _onError?.call(e);
      }
      final prevIndex = index - 1;
      if (prevIndex >= 0) {
        _playerPrev.setUrl(_reels[prevIndex].audioUrl).catchError((_) => null);
      }
      completer.complete();
      return;
    }

    // Cold jump: load into current, preload prev and next. Use URL for instant start.
    _audioCache?.prefetchAround(index, _reels);
    try {
      if (gen != _generation) {
        completer.complete();
        return;
      }
      await _playerCurrent.stop();
      if (gen != _generation || _disposed) {
        completer.complete();
        return;
      }
      final url = _reels[index].audioUrl;
      if (url.isEmpty || gen != _generation || _disposed) {
        completer.complete();
        return;
      }
      await _playerCurrent.setUrl(url);
      if (gen != _generation || _disposed) {
        completer.complete();
        return;
      }
      _currentReelIndex = index;
      state.value = state.value.copyWith(currentIndex: index);
      _lastPosition = Duration.zero;
      _lastDuration = null;
      _emitPositionDuration();
      await _playerCurrent.play();
      if (gen != _generation || _disposed) {
        completer.complete();
        return;
      }
      state.value = state.value.copyWith(isPlaying: true);

      final prevIndex = index - 1;
      if (prevIndex >= 0) {
        _playerPrev.setUrl(_reels[prevIndex].audioUrl).catchError((_) => null);
      }
      final nextIndex = index + 1;
      if (nextIndex < _reels.length) {
        _playerNext.setUrl(_reels[nextIndex].audioUrl).catchError((_) => null);
      }
    } catch (e) {
      if (_isIgnorableAudioException(e)) {
        completer.complete();
        return;
      }
      if (gen == _generation) _onError?.call(e);
    }
    completer.complete();
  }

  void _rotateForward() {
    final newSlotPrev = _slotCurrent;
    final newSlotCurrent = _slotNext;
    final newSlotNext = _slotPrev;
    _slotPrev = newSlotPrev;
    _slotCurrent = newSlotCurrent;
    _slotNext = newSlotNext;
  }

  void _rotateBackward() {
    final newSlotPrev = _slotNext;
    final newSlotCurrent = _slotPrev;
    final newSlotNext = _slotCurrent;
    _slotPrev = newSlotPrev;
    _slotCurrent = newSlotCurrent;
    _slotNext = newSlotNext;
  }

  Future<void> _resume(int gen) async {
    try {
      await _playerCurrent.play();
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
      await _playerCurrent.pause();
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
    }
    state.value = state.value.copyWith(isPlaying: false);
  }

  Future<void> pauseForAppBackground() async {
    if (_disposed) return;
    if (_currentReelIndex >= 0) _wasPlayingBeforeAppPause = true;
    try {
      await _playerCurrent.pause();
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
    }
    state.value = state.value.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    if (_disposed || _currentReelIndex < 0 || !_wasPlayingBeforeAppPause) return;
    try {
      await _playerCurrent.play();
    } catch (e) {
      if (_isIgnorableAudioException(e)) return;
    }
    state.value = state.value.copyWith(isPlaying: true);
  }

  Future<void> togglePlayPause() async {
    if (_disposed || _currentReelIndex < 0) return;
    if (state.value.isPlaying) {
      await _playerCurrent.pause();
      state.value = state.value.copyWith(isPlaying: false);
    } else {
      try {
        await _playerCurrent.play();
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
    _lastPosition = player.position;
    _lastDuration = player.duration;
    _emitPositionDuration();

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
      if (_disposed) return;
      _lastPosition = p;
      _emitPositionDuration();
    });
    _durationSub = player.durationStream.listen((d) {
      if (_disposed) return;
      _lastDuration = d;
      _emitPositionDuration();
    });
  }

  void attach() {
    for (final p in _players) {
      p.setLoopMode(LoopMode.one);
    }
    _subscribeTo(_playerCurrent);
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed || !_playerCurrent.playing) return;
      _lastPosition = _playerCurrent.position;
      if (_lastDuration == null) {
        final d = _playerCurrent.duration;
        if (d != null) _lastDuration = d;
      }
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
    for (final p in _players) {
      p.dispose();
    }
  }
}
