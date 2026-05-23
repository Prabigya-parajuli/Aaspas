import 'package:flutter_test/flutter_test.dart';
import 'package:aaspas/utils/input_validator.dart';

void main() {
  group('InputValidator - Email Validation', () {
    test('Valid email should return null', () {
      expect(InputValidator.validateEmail('user@example.com'), null);
      expect(InputValidator.validateEmail('test@gmail.com'), null);
      expect(InputValidator.validateEmail('name@ncmt.edu.np'), null);
    });

    test('Invalid email should return error message', () {
      expect(InputValidator.validateEmail(''), isNotNull);
      expect(InputValidator.validateEmail('user@'), isNotNull);
      expect(InputValidator.validateEmail('user.com'), isNotNull);
      expect(InputValidator.validateEmail('user@.com'), isNotNull);
    });
  });

  group('InputValidator - Title Validation', () {
    test('Valid title (3-100 chars) should return null', () {
      expect(InputValidator.validateTitle('Blood Donation'), null);
      expect(InputValidator.validateTitle('Tech Meetup'), null);
    });

    test('Empty title should return error', () {
      expect(InputValidator.validateTitle(''), isNotNull);
    });

    test('Title too short (<3 chars) should return error', () {
      expect(InputValidator.validateTitle('Hi'), isNotNull);
    });

    test('Title too long (>100 chars) should return error', () {
      String longTitle = 'a' * 101;
      expect(InputValidator.validateTitle(longTitle), isNotNull);
    });
  });

  group('InputValidator - Password Validation', () {
    test('Valid password (6+ chars) should return null', () {
      expect(InputValidator.validatePassword('password123'), null);
      expect(InputValidator.validatePassword('Test@123'), null);
    });

    test('Empty password should return error', () {
      expect(InputValidator.validatePassword(''), isNotNull);
    });

    test('Short password (<6 chars) should return error', () {
      expect(InputValidator.validatePassword('12345'), isNotNull);
    });
  });
}