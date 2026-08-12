import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/game_state.dart';
import '../models/statistics.dart';
import '../models/game_settings.dart';
import '../models/player_profile.dart';

class CorruptedSaveException implements Exception {
  final String message;
  CorruptedSaveException(this.message);
  @override
  String toString() => 'CorruptedSaveException: $message';
}

class PersistenceManager {
  static final PersistenceManager _instance = PersistenceManager._internal();
  factory PersistenceManager() => _instance;
  PersistenceManager._internal();

  static const String _gameSaveFileName = 'letterloom_save_v1.json';
  static const String _statsSaveFileName = 'letterloom_stats_v1.json';
  static const String _settingsSaveFileName = 'letterloom_settings_v1.json';

  Future<File> _getFile(String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  // --- Active Game Persistence ---

  Future<void> saveGame(GameState state, {DateTime? clockNow}) async {
    try {
      final file = await _getFile(_gameSaveFileName);
      // A finished match is a result screen, never a resumable match. This
      // also protects against a lifecycle callback firing just after end-game
      // cleanup while the victory screen remains visible.
      if (state.status == 'gameCompleted') {
        if (await file.exists()) await file.delete();
        return;
      }
      final now = clockNow ?? DateTime.now();
      final remaining = state.turnStartedAt == null
          ? null
          : (GameState.turnDurationSeconds -
                    now.difference(state.turnStartedAt!).inSeconds)
                .clamp(0, GameState.turnDurationSeconds);
      final payload = <String, dynamic>{
        ...state.toJson(),
        'turnSecondsRemaining': remaining,
        'saveMode': 'solo',
      };
      final jsonString = jsonEncode(payload);
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint("Error saving game state: $e");
    }
  }

  Future<GameState?> loadGame() async {
    try {
      final file = await _getFile(_gameSaveFileName);
      if (!await file.exists()) {
        return null;
      }
      final String jsonString = await file.readAsString();
      if (jsonString.isEmpty) return null;

      final Map<String, dynamic> jsonMap =
          jsonDecode(jsonString) as Map<String, dynamic>;
      final savedGame = GameState.fromJson(jsonMap);
      if (savedGame.status == 'gameCompleted') {
        await file.delete();
        return null;
      }
      return savedGame;
    } catch (e) {
      debugPrint("Error loading game state (likely corruption): $e");
      throw CorruptedSaveException(
        "The saved game file is corrupted or incompatible.",
      );
    }
  }

  Future<void> deleteGameSave() async {
    try {
      final file = await _getFile(_gameSaveFileName);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Error deleting game save: $e");
    }
  }

  Future<bool> hasSavedGame() async {
    try {
      final file = await _getFile(_gameSaveFileName);
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return false;

      final payload = jsonDecode(content) as Map<String, dynamic>;
      // Repair stale saves created by the older lifecycle code while a result
      // screen was visible. Completed matches must not surface as Continue.
      if (payload['status'] == 'gameCompleted') {
        await file.delete();
        return false;
      }
      if (payload['saveMode'] == 'solo') return true;

      // Older builds could accidentally persist a temporary multiplayer seed.
      // Treat that untouched seed as no active solo game and remove it once.
      final board = payload['board'];
      final moves = payload['moveHistory'];
      final untouchedSeed =
          payload['lastMoveMessage'] == 'New game started! Your turn first.' &&
          payload['playerScore'] == 0 &&
          payload['computerScore'] == 0 &&
          moves is List &&
          moves.isEmpty &&
          board is List &&
          board.every(
            (row) =>
                row is List &&
                row.every(
                  (cell) =>
                      cell is Map<String, dynamic> && cell['tile'] == null,
                ),
          );
      if (untouchedSeed) {
        await file.delete();
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Statistics Persistence ---

  Future<void> saveStatistics(Statistics stats) async {
    try {
      final file = await _getFile(_statsSaveFileName);
      final jsonString = jsonEncode(stats.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint("Error saving statistics: $e");
    }
  }

  Future<Statistics> loadStatistics() async {
    try {
      final file = await _getFile(_statsSaveFileName);
      if (!await file.exists()) {
        return const Statistics();
      }
      final String jsonString = await file.readAsString();
      if (jsonString.isEmpty) return const Statistics();

      final Map<String, dynamic> jsonMap =
          jsonDecode(jsonString) as Map<String, dynamic>;
      return Statistics.fromJson(jsonMap);
    } catch (e) {
      debugPrint("Error loading statistics, resetting to default: $e");
      return const Statistics();
    }
  }

  // --- Settings Persistence ---

  Future<void> saveSettings(GameSettings settings) async {
    try {
      final file = await _getFile(_settingsSaveFileName);
      final jsonString = jsonEncode(settings.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint("Error saving settings: $e");
    }
  }

  Future<GameSettings> loadSettings() async {
    try {
      final file = await _getFile(_settingsSaveFileName);
      if (!await file.exists()) {
        return const GameSettings();
      }
      final String jsonString = await file.readAsString();
      if (jsonString.isEmpty) return const GameSettings();

      final Map<String, dynamic> jsonMap =
          jsonDecode(jsonString) as Map<String, dynamic>;
      return GameSettings.fromJson(jsonMap);
    } catch (e) {
      debugPrint("Error loading settings, resetting to default: $e");
      return const GameSettings();
    }
  }

  // --- Profile Persistence ---

  // Keep guest and authenticated identities independent. Signing out must not
  // replace the last signed-in profile with a newly generated guest profile.
  static const String _legacyProfileSaveFileName = 'letterloom_profile_v2.json';
  static const String _guestProfileSaveFileName =
      'letterloom_guest_profile_v1.json';
  static const String _accountProfileSaveFileName =
      'letterloom_account_profile_v1.json';

  Future<void> saveProfile(PlayerProfile profile) async {
    if (profile.isGuest) {
      await saveGuestProfile(profile);
    } else {
      await saveAuthenticatedProfile(profile);
    }
  }

  Future<void> saveGuestProfile(PlayerProfile profile) async {
    await _saveProfile(_guestProfileSaveFileName, profile);
  }

  Future<void> saveAuthenticatedProfile(PlayerProfile profile) async {
    await _saveProfile(_accountProfileSaveFileName, profile);
  }

  Future<void> _saveProfile(String fileName, PlayerProfile profile) async {
    try {
      final file = await _getFile(fileName);
      final jsonString = jsonEncode(profile.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint("Error saving profile: $e");
    }
  }

  Future<PlayerProfile?> loadProfile() async {
    final guest = await loadGuestProfile();
    return guest ?? loadAuthenticatedProfile();
  }

  Future<PlayerProfile?> loadGuestProfile() async {
    final saved = await _loadProfile(_guestProfileSaveFileName);
    if (saved != null) return saved.isGuest ? saved : null;
    final legacy = await _loadProfile(_legacyProfileSaveFileName);
    return legacy?.isGuest == true ? legacy : null;
  }

  Future<PlayerProfile?> loadAuthenticatedProfile() async {
    final saved = await _loadProfile(_accountProfileSaveFileName);
    if (saved != null) return saved.isGuest ? null : saved;
    final legacy = await _loadProfile(_legacyProfileSaveFileName);
    return legacy?.isGuest == false ? legacy : null;
  }

  Future<PlayerProfile?> _loadProfile(String fileName) async {
    try {
      final file = await _getFile(fileName);
      if (!await file.exists()) return null;
      final String jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) return null;
      final Map<String, dynamic> jsonMap =
          jsonDecode(jsonString) as Map<String, dynamic>;
      return PlayerProfile.fromJson(jsonMap);
    } catch (e) {
      debugPrint("Error loading profile: $e");
      return null;
    }
  }

  // --- Generic JSON Payload Persistence (Hints, Achievements, Cosmetics, Challenges, Missions) ---

  Future<void> saveJsonData(String fileName, Map<String, dynamic> data) async {
    try {
      final file = await _getFile(fileName);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint("Error saving $fileName: $e");
    }
  }

  Future<Map<String, dynamic>?> loadJsonData(String fileName) async {
    try {
      final file = await _getFile(fileName);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error loading $fileName: $e");
      return null;
    }
  }
}
