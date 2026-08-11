import 'dart:math';

class UsernameValidationResult {
  final bool isValid;
  final String? errorMessage;
  const UsernameValidationResult({required this.isValid, this.errorMessage});
  factory UsernameValidationResult.valid() => const UsernameValidationResult(isValid: true);
  factory UsernameValidationResult.invalid(String message) =>
      UsernameValidationResult(isValid: false, errorMessage: message);
}

class UsernameGenerator {
  static final Random _random = Random();

  static const List<String> adjectives = [
    'Quiet', 'Jolly', 'Rapid', 'Clever', 'Sleepy', 'Gentle', 'Lucky', 'Velvet',
    'Noble', 'Golden', 'Brave', 'Crafty', 'Swift', 'Starlight', 'Solar', 'Amber',
    'Silver', 'Sly', 'Witty', 'Charming', 'Radiant', 'Cosmic', 'Nimble', 'Keen',
    'Frosty', 'Mellow', 'Brisk', 'Vibrant', 'Serene', 'Luminous', 'Wandering',
    'Silent', 'Mystic', 'Gallant', 'Feisty', 'Daring', 'Zealous', 'Curious',
    'Subtle', 'Bold', 'Bright', 'Valiant', 'Polished', 'Ornate', 'Grand', 'Spry'
  ];

  static const List<String> nouns = [
    'Falcon', 'Cactus', 'Otter', 'Mango', 'Knight', 'Rocket', 'Walrus', 'Weaver',
    'Loomer', 'Panther', 'Badger', 'Phoenix', 'Dolphin', 'Raven', 'Tiger', 'Sparrow',
    'Bison', 'Panda', 'Lynx', 'Viper', 'Falcon', 'Heron', 'Koala', 'Dragon',
    'Griffin', 'Puffin', 'Breeze', 'Anchor', 'Beacon', 'Scepter', 'Monarch',
    'Scholar', 'Warden', 'Sentry', 'Voyager', 'Pioneer', 'Orbiter', 'Eclipse',
    'Solstice', 'Sentinel', 'Scribe', 'Archon', 'Nomad', 'Strider', 'Oracle'
  ];

  static const Set<String> reservedNames = {
    'admin',
    'administrator',
    'moderator',
    'letterloom',
    'support',
    'official',
    'system',
    'root',
    'superuser',
    'helpdesk',
    'security',
    'guest',
    'null',
    'undefined',
  };

  static const Set<String> offensiveTerms = {
    'badword',
    'profanity',
    'hate',
    'scam',
    'abuse',
  };

  /// Generates a funny gamer-style username.
  static String generateFunnyUsername() {
    final adj = adjectives[_random.nextInt(adjectives.length)];
    final noun = nouns[_random.nextInt(nouns.length)];
    return '$adj$noun';
  }

  /// Appends a small random suffix number to a base username.
  static String generateWithSuffix(String baseUsername) {
    final num = _random.nextInt(90) + 10; // 10 to 99
    return '$baseUsername$num';
  }

  /// Normalizes a user-input username (trim, preserve case for display).
  static String normalize(String input) {
    return input.trim().toLowerCase();
  }

  /// Validate username format, length, reserved words, and profanity.
  static UsernameValidationResult validate(String rawInput) {
    final normalized = normalize(rawInput);
    if (normalized.isEmpty) {
      return UsernameValidationResult.invalid('Username cannot be empty.');
    }

    if (normalized.length < 3) {
      return UsernameValidationResult.invalid('Username must be at least 3 characters.');
    }

    if (normalized.length > 20) {
      return UsernameValidationResult.invalid('Username must be 20 characters or fewer.');
    }

    final RegExp validChars = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validChars.hasMatch(normalized)) {
      return UsernameValidationResult.invalid('Username can only contain letters, numbers, and underscores.');
    }

    final lower = normalized.toLowerCase();

    for (final reserved in reservedNames) {
      if (lower == reserved || lower.contains('letterloom')) {
        return UsernameValidationResult.invalid('This username is reserved by the system.');
      }
    }

    for (final term in offensiveTerms) {
      if (lower.contains(term)) {
        return UsernameValidationResult.invalid('This username contains inappropriate terms.');
      }
    }

    return UsernameValidationResult.valid();
  }
}
