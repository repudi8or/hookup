import 'package:flutter_test/flutter_test.dart';
import 'package:hookup/src/profile_model.dart';

void main() {
  group('ProfileModel.isComplete', () {
    test('returns false when photoUrl is null', () {
      final profile = ProfileModel(
        name: 'Alice',
        bio: 'Hey there',
        photoUrl: null,
      );
      expect(profile.isComplete, isFalse);
    });

    test('returns false when name is empty', () {
      final profile = ProfileModel(
        name: '',
        bio: 'Hey there',
        photoUrl: 'https://example.com/photo.jpg',
      );
      expect(profile.isComplete, isFalse);
    });

    test('returns false when bio is empty', () {
      final profile = ProfileModel(
        name: 'Alice',
        bio: '',
        photoUrl: 'https://example.com/photo.jpg',
      );
      expect(profile.isComplete, isFalse);
    });

    test('returns false when all fields are missing', () {
      final profile = ProfileModel(name: '', bio: '', photoUrl: null);
      expect(profile.isComplete, isFalse);
    });

    test('returns true when all required fields are present', () {
      final profile = ProfileModel(
        name: 'Alice',
        bio: 'Hey there',
        photoUrl: 'https://example.com/photo.jpg',
      );
      expect(profile.isComplete, isTrue);
    });
  });

  group('ProfileModel.copyWith', () {
    test('updates only the specified fields', () {
      final profile = ProfileModel(
        name: 'Alice',
        bio: 'Hey there',
        photoUrl: 'https://example.com/photo.jpg',
      );
      final updated = profile.copyWith(name: 'Bob');
      expect(updated.name, equals('Bob'));
      expect(updated.bio, equals('Hey there'));
      expect(updated.photoUrl, equals('https://example.com/photo.jpg'));
    });

    test('clearing photoUrl makes profile incomplete', () {
      final profile = ProfileModel(
        name: 'Alice',
        bio: 'Hey there',
        photoUrl: 'https://example.com/photo.jpg',
      );
      expect(profile.isComplete, isTrue);
      final cleared = profile.copyWith(photoUrl: null, clearPhotoUrl: true);
      expect(cleared.isComplete, isFalse);
    });
  });

  group('ProfileModel — optional context fields', () {
    test('all optional fields default to null', () {
      final profile = ProfileModel(name: 'Alice', bio: 'Hey', photoUrl: null);
      expect(profile.gender, isNull);
      expect(profile.age, isNull);
      expect(profile.height, isNull);
      expect(profile.bodyShape, isNull);
      expect(profile.hairColour, isNull);
    });

    test('isComplete is unaffected by optional context fields', () {
      final profile = ProfileModel(
        name: 'Alice',
        bio: 'Hey',
        photoUrl: 'url',
        gender: 'Woman',
        age: 28,
        height: 168,
        bodyShape: 'Slim',
        hairColour: 'Blonde',
      );
      expect(profile.isComplete, isTrue);
    });

    test('copyWith updates optional context fields independently', () {
      final base = ProfileModel(
        name: 'Alice',
        bio: 'Hey',
        photoUrl: null,
        gender: 'Woman',
        age: 28,
        height: 168,
        bodyShape: 'Slim',
        hairColour: 'Blonde',
      );
      final updated = base.copyWith(age: 29, hairColour: 'Red');
      expect(updated.age, equals(29));
      expect(updated.hairColour, equals('Red'));
      // Unchanged fields preserved.
      expect(updated.gender, equals('Woman'));
      expect(updated.height, equals(168));
      expect(updated.bodyShape, equals('Slim'));
    });
  });
}
