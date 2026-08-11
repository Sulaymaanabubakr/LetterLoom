import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/features/profile/username_generator.dart';

void main() {
  group('UsernameGenerator Tests', () {
    test('generateFunnyUsername returns valid combination', () {
      final username = UsernameGenerator.generateFunnyUsername();
      expect(username, isNotEmpty);
      final validation = UsernameGenerator.validate(username);
      expect(validation.isValid, isTrue);
    });

    test('validate accepts valid alphanumeric usernames', () {
      final res = UsernameGenerator.validate('CleverMango_99');
      expect(res.isValid, isTrue);
    });

    test('validate rejects short usernames (< 3 chars)', () {
      final res = UsernameGenerator.validate('ab');
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('at least 3 characters'));
    });

    test('validate rejects long usernames (> 20 chars)', () {
      final res = UsernameGenerator.validate('ThisIsAUsernameThatIsFarTooLong');
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('20 characters or fewer'));
    });

    test('validate rejects reserved system names', () {
      expect(UsernameGenerator.validate('admin').isValid, isFalse);
      expect(UsernameGenerator.validate('LetterLoomSupport').isValid, isFalse);
      expect(UsernameGenerator.validate('system').isValid, isFalse);
    });

    test('generateWithSuffix appends number suffix', () {
      final suffixed = UsernameGenerator.generateWithSuffix('CleverMango');
      expect(suffixed, startsWith('CleverMango'));
      expect(suffixed.length, greaterThan('CleverMango'.length));
    });
  });
}
