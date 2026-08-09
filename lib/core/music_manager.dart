import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Which music context we are in
enum MusicTrack { menu, game }

/// Singleton that manages background music playback from bundled assets.
/// - Menu: Satie's Gymnopédie No. 1 — warm, welcoming piano.
/// - Game: Kalimba Relaxation Music — calm, cozy thumb-piano to aid focus.
/// Both tracks are Kevin MacLeod recordings under CC Attribution 4.0 (incompetech.com).
class MusicManager {
  static final MusicManager instance = MusicManager._internal();
  MusicManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _musicEnabled = false;
  MusicTrack _currentTrack = MusicTrack.menu;

  // Bundled local assets — instant playback, no network required
  static const Map<MusicTrack, String> _trackAssets = {
    MusicTrack.menu: 'audio/menu_music.mp3',
    MusicTrack.game: 'audio/game_music.mp3',
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once on app startup with the user's saved preference.
  Future<void> init(bool musicEnabled) async {
    if (_isInitialized) return;
    _musicEnabled = musicEnabled;
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.10);
      _isInitialized = true;
      if (_musicEnabled) _playCurrentTrack();
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
    if (enabled) {
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
    if (_musicEnabled && _isInitialized) {
      _playCurrentTrack();
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Fire-and-forget using local AssetSource — plays immediately from disk.
  void _playCurrentTrack() {
    final asset = _trackAssets[_currentTrack]!;
    _audioPlayer.play(AssetSource(asset)).catchError((e) {
      debugPrint('MusicManager: error playing $_currentTrack: $e');
    });
  }

  void _stopMusic() {
    _audioPlayer.stop().catchError((e) {
      debugPrint('MusicManager: error stopping music: $e');
    });
  }
}
