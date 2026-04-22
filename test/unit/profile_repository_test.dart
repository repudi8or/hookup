import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookup/src/profile_bundle_codec.dart';
import 'package:hookup/src/profile_model.dart';
import 'package:hookup/src/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;
  late File photoFile;
  late ProfileRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('profile_repo_test_');
    photoFile = File('${tempDir.path}/profile_photo.jpg');
    final prefs = await SharedPreferences.getInstance();
    repo = ProfileRepository(prefs, photoFile);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('ProfileRepository.load', () {
    test('returns null when nothing has been saved', () async {
      expect(await repo.load(), isNull);
    });
  });

  group('ProfileRepository.save + load round-trip', () {
    test('restores required fields', () async {
      await repo.save(
        ProfileBundle(
          profile: const ProfileModel(
            name: 'Alice',
            bio: 'Hey',
            photoUrl: 'local',
          ),
          photoBytes: Uint8List.fromList([1, 2, 3]),
        ),
      );
      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.profile.name, equals('Alice'));
      expect(loaded.profile.bio, equals('Hey'));
      expect(loaded.photoBytes, equals([1, 2, 3]));
    });

    test(
      'restored profile has isComplete = true when photo was saved',
      () async {
        await repo.save(
          ProfileBundle(
            profile: const ProfileModel(
              name: 'Alice',
              bio: 'Hey',
              photoUrl: 'local',
            ),
            photoBytes: Uint8List.fromList([1, 2, 3]),
          ),
        );
        final loaded = await repo.load();
        expect(loaded!.profile.isComplete, isTrue);
      },
    );

    test('restores optional fields', () async {
      await repo.save(
        ProfileBundle(
          profile: const ProfileModel(
            name: 'Bob',
            bio: 'Hi',
            photoUrl: 'local',
            gender: 'Man',
            age: 30,
            height: 180,
            bodyShape: 'Athletic',
            hairColour: 'Blonde',
          ),
          photoBytes: Uint8List.fromList([9, 8, 7]),
        ),
      );
      final loaded = await repo.load();
      expect(loaded!.profile.gender, equals('Man'));
      expect(loaded.profile.age, equals(30));
      expect(loaded.profile.height, equals(180));
      expect(loaded.profile.bodyShape, equals('Athletic'));
      expect(loaded.profile.hairColour, equals('Blonde'));
    });

    test('optional fields are null when not saved', () async {
      await repo.save(
        ProfileBundle(
          profile: const ProfileModel(
            name: 'Alice',
            bio: 'Hey',
            photoUrl: 'local',
          ),
          photoBytes: Uint8List.fromList([1]),
        ),
      );
      final loaded = await repo.load();
      expect(loaded!.profile.gender, isNull);
      expect(loaded.profile.age, isNull);
      expect(loaded.profile.height, isNull);
      expect(loaded.profile.bodyShape, isNull);
      expect(loaded.profile.hairColour, isNull);
    });

    test('overwrite replaces previous values', () async {
      await repo.save(
        ProfileBundle(
          profile: const ProfileModel(
            name: 'Alice',
            bio: 'Old',
            photoUrl: 'local',
          ),
          photoBytes: Uint8List.fromList([1]),
        ),
      );
      await repo.save(
        ProfileBundle(
          profile: const ProfileModel(
            name: 'Alice',
            bio: 'New',
            photoUrl: 'local',
          ),
          photoBytes: Uint8List.fromList([2, 3]),
        ),
      );
      final loaded = await repo.load();
      expect(loaded!.profile.bio, equals('New'));
      expect(loaded.photoBytes, equals([2, 3]));
    });
  });

  group('ProfileRepository photo file', () {
    test('empty photoBytes does not write a file', () async {
      await repo.save(
        ProfileBundle(
          profile: const ProfileModel(
            name: 'Alice',
            bio: 'Hey',
            photoUrl: 'local',
          ),
          photoBytes: Uint8List(0),
        ),
      );
      expect(await photoFile.exists(), isFalse);
    });

    test(
      'saving empty photoBytes after a prior photo deletes the file',
      () async {
        await repo.save(
          ProfileBundle(
            profile: const ProfileModel(
              name: 'Alice',
              bio: 'Hey',
              photoUrl: 'local',
            ),
            photoBytes: Uint8List.fromList([1, 2, 3]),
          ),
        );
        expect(await photoFile.exists(), isTrue);

        await repo.save(
          ProfileBundle(
            profile: const ProfileModel(
              name: 'Alice',
              bio: 'Hey',
              photoUrl: 'local',
            ),
            photoBytes: Uint8List(0),
          ),
        );
        expect(await photoFile.exists(), isFalse);
      },
    );

    test('profile without photo has isComplete = false', () async {
      await repo.save(
        ProfileBundle(
          profile: const ProfileModel(
            name: 'Alice',
            bio: 'Hey',
            photoUrl: 'local',
          ),
          photoBytes: Uint8List(0),
        ),
      );
      final loaded = await repo.load();
      expect(loaded!.profile.isComplete, isFalse);
    });
  });

  group('ProfileRepository photo compression', () {
    test('save passes photo bytes through the injected compressor', () async {
      final calls = <Uint8List>[];
      final compressedBytes = Uint8List.fromList([9, 8, 7]);
      final prefs = await SharedPreferences.getInstance();

      final repoWithCompressor = ProfileRepository(
        prefs,
        photoFile,
        compressor: (bytes) async {
          calls.add(bytes);
          return compressedBytes;
        },
      );

      final original = Uint8List.fromList([1, 2, 3, 4, 5]);
      await repoWithCompressor.save(
        ProfileBundle(
          profile: const ProfileModel(
            name: 'Alice',
            bio: 'Hey',
            photoUrl: 'local',
          ),
          photoBytes: original,
        ),
      );

      expect(calls, hasLength(1));
      expect(calls.first, equals(original));

      final loaded = await repoWithCompressor.load();
      expect(loaded!.photoBytes, equals(compressedBytes));
    });

    test('compressor is not called when photoBytes is empty', () async {
      var called = false;
      final prefs = await SharedPreferences.getInstance();

      final repoWithCompressor = ProfileRepository(
        prefs,
        photoFile,
        compressor: (_) async {
          called = true;
          return Uint8List(0);
        },
      );

      await repoWithCompressor.save(
        ProfileBundle(
          profile: const ProfileModel(
            name: 'Alice',
            bio: 'Hey',
            photoUrl: 'local',
          ),
          photoBytes: Uint8List(0),
        ),
      );

      expect(called, isFalse);
    });
  });
}
