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
}
