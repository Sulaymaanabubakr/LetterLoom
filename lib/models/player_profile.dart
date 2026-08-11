import 'package:flutter/foundation.dart';
import '../core/app_config.dart';

@immutable
class PlayerProfile {
  final String id;
  final String username;
  final String displayName;
  final String avatarId;
  final String countryCode;
  final bool isGuest;
  final int level;
  final int xp;
  final String rankedTier;
  final int rankedRating;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final int highestScore;
  final int currentStreak;
  final int bestStreak;
  final DateTime createdAt;

  const PlayerProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarId,
    required this.countryCode,
    this.isGuest = true,
    this.level = 1,
    this.xp = 0,
    this.rankedTier = 'Bronze III',
    this.rankedRating = AppConfig.defaultRankedRating,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.highestScore = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    required this.createdAt,
  });

  /// Generate a default Guest profile.
  factory PlayerProfile.guest({
    required String id,
    required String funnyUsername,
    String? displayName,
    String avatarId = 'avatar_owl',
    String countryCode = 'US',
  }) {
    return PlayerProfile(
      id: id,
      username: funnyUsername,
      displayName: displayName ?? funnyUsername,
      avatarId: avatarId,
      countryCode: countryCode,
      isGuest: true,
      level: 1,
      xp: 0,
      rankedTier: 'Bronze III',
      rankedRating: AppConfig.defaultRankedRating,
      createdAt: DateTime.now(),
    );
  }

  PlayerProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarId,
    String? countryCode,
    bool? isGuest,
    int? level,
    int? xp,
    String? rankedTier,
    int? rankedRating,
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? draws,
    int? highestScore,
    int? currentStreak,
    int? bestStreak,
    DateTime? createdAt,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
      countryCode: countryCode ?? this.countryCode,
      isGuest: isGuest ?? this.isGuest,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      rankedTier: rankedTier ?? this.rankedTier,
      rankedRating: rankedRating ?? this.rankedRating,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      highestScore: highestScore ?? this.highestScore,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'lower_username': username.toLowerCase(),
      'display_name': displayName,
      'avatar_id': avatarId,
      'country_code': countryCode,
      'is_guest': isGuest,
      'level': level,
      'xp': xp,
      'ranked_tier': rankedTier,
      'ranked_rating': rankedRating,
      'games_played': gamesPlayed,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'highest_score': highestScore,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Gamer',
      displayName: json['display_name'] as String? ?? json['username'] as String? ?? 'Gamer',
      avatarId: json['avatar_id'] as String? ?? 'avatar_owl',
      countryCode: json['country_code'] as String? ?? 'US',
      isGuest: json['is_guest'] as bool? ?? false,
      level: json['level'] as int? ?? 1,
      xp: json['xp'] as int? ?? 0,
      rankedTier: json['ranked_tier'] as String? ?? 'Bronze III',
      rankedRating: json['ranked_rating'] as int? ?? AppConfig.defaultRankedRating,
      gamesPlayed: json['games_played'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      highestScore: json['highest_score'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      bestStreak: json['best_streak'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
