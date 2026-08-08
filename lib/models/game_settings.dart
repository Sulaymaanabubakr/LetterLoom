class GameSettings {
  final bool soundEnabled;
  final bool hapticEnabled;
  final bool musicEnabled;
  final double animationSpeed; // 1.0 is normal, 0.5 is fast (i.e. animation duration is halved)

  const GameSettings({
    this.soundEnabled = true,
    this.hapticEnabled = true,
    this.musicEnabled = true,
    this.animationSpeed = 1.0,
  });

  GameSettings copyWith({
    bool? soundEnabled,
    bool? hapticEnabled,
    bool? musicEnabled,
    double? animationSpeed,
  }) {
    return GameSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      animationSpeed: animationSpeed ?? this.animationSpeed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'soundEnabled': soundEnabled,
      'hapticEnabled': hapticEnabled,
      'musicEnabled': musicEnabled,
      'animationSpeed': animationSpeed,
    };
  }

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      hapticEnabled: json['hapticEnabled'] as bool? ?? true,
      musicEnabled: json['musicEnabled'] as bool? ?? true,
      animationSpeed: (json['animationSpeed'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
