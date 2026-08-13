import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Which music context we are in
enum MusicTrack { menu, game }

/// Singleton that manages background music playback from bundled assets.
/// - Menu: Midsummer Sky — welcoming, gentle piano.
/// - Game: Sapphire Isle — calm piano for focused play.
/// Both tracks are Kevin MacLeod recordings under CC Attribution 4.0 (incompetech.com).
class MusicManager with WidgetsBindingObserver {
  static final MusicManager instance = MusicManager._internal();
  MusicManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _musicEnabled = false;
  bool _isAppResumed = true;
  bool _isObservingLifecycle = false;
  bool _pausedForLifecycle = false;
  bool _voiceChatActive = false;
  bool _pausedForVoice = false;
  MusicTrack _currentTrack = MusicTrack.menu;

  // Bundled local assets — instant playback, no network required
  static const Map<MusicTrack, String> _trackAssets = {
    MusicTrack.menu: 'audio/menu_music.m4a',
    MusicTrack.game: 'audio/game_music.m4a',
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once on app startup with the user's saved preference.
  Future<void> init(bool musicEnabled) async {
    if (_isInitialized) return;
    _musicEnabled = musicEnabled;
    try {
      if (!_isObservingLifecycle) {
        WidgetsBinding.instance.addObserver(this);
        _isObservingLifecycle = true;
      }
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Keep the player at full media gain. Volume is deliberately owned by
      // Android/iOS media controls, so players use their phone volume buttons
      // rather than an arbitrary in-app cap.
      await _audioPlayer.setVolume(1.0);
      _isInitialized = true;
      if (_musicEnabled && _isAppResumed) _playCurrentTrack();
    } catch (e) {
      debugPrint('MusicManager init error: $e');
    }
  }

  /// Toggle music on/off (called from settings switch).
  Future<void> updateMusicState(bool enabled) async {
    _musicEnabled = enabled;
    if (!_isInitialized) {
      await init(enabled);
      return;
    }
    if (enabled && _isAppResumed && !_voiceChatActive) {
      _playCurrentTrack();
    } else {
      _stopMusic();
    }
  }

  /// Switch between menu and game tracks — synchronous, never blocks navigation.
  /// Safe to call even when music is disabled — remembers the track for later.
  void setTrack(MusicTrack track) {
    if (_currentTrack == track) return;
    _currentTrack = track;
    if (_musicEnabled && _isInitialized && _isAppResumed && !_voiceChatActive) {
      _playCurrentTrack();
    }
  }

  /// Pause local playback while the microphone is live to avoid acoustic echo.
  Future<void> setVoiceChatActive(bool active) async {
    if (_voiceChatActive == active) return;
    _voiceChatActive = active;
    if (!_isInitialized || !_musicEnabled) return;

    if (active && _isAppResumed) {
      try {
        await _audioPlayer.pause();
        _pausedForVoice = true;
      } catch (e) {
        debugPrint('MusicManager: error pausing for voice chat: $e');
      }
    } else if (!active && _pausedForVoice && _isAppResumed) {
      try {
        await _audioPlayer.resume();
        _pausedForVoice = false;
      } catch (e) {
        debugPrint('MusicManager: error resuming after voice chat: $e');
        _playCurrentTrack();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _isAppResumed;
    _isAppResumed = state == AppLifecycleState.resumed;

    if (!_isInitialized || !_musicEnabled) return;

    if (!_isAppResumed) {
      _pauseForLifecycle();
    } else if (!wasResumed && !_voiceChatActive) {
      _resumeAfterLifecycle();
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Fire-and-forget using local AssetSource — plays immediately from disk.
  void _playCurrentTrack() {
    if (_voiceChatActive) return;
    _pausedForLifecycle = false;
    final asset = _trackAssets[_currentTrack]!;
    _audioPlayer.play(AssetSource(asset)).catchError((e) {
      debugPrint('MusicManager: error playing $_currentTrack: $e');
    });
  }

  void _stopMusic() {
    _pausedForLifecycle = false;
    _audioPlayer.stop().catchError((e) {
      debugPrint('MusicManager: error stopping music: $e');
    });
  }

  /// Preserve playback position when Android/iOS backgrounds the app. Calling
  /// `stop` here resets an AssetSource to the beginning, which made game music
  /// restart every time a paused match was resumed.
  void _pauseForLifecycle() {
    _audioPlayer
        .pause()
        .then((_) {
          _pausedForLifecycle = true;
        })
        .catchError((e) {
          debugPrint('MusicManager: error pausing music: $e');
        });
  }

  void _resumeAfterLifecycle() {
    if (_pausedForLifecycle) {
      _audioPlayer
          .resume()
          .then((_) {
            _pausedForLifecycle = false;
          })
          .catchError((e) {
            debugPrint('MusicManager: error resuming music: $e');
            _playCurrentTrack();
          });
      return;
    }
    _playCurrentTrack();
  }
}
