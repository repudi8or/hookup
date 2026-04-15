import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookup/src/profile_bundle_codec.dart';
import 'package:hookup/src/profile_model.dart';

void main() {
  // Minimal fake JPEG bytes for use across tests.
  final fakePhoto = Uint8List.fromList(List.generate(500, (i) => i % 256));

  final completeProfile = ProfileModel(
    name: 'Alice',
    bio: 'Hey there',
    photoUrl: 'https://example.com/photo.jpg',
  );

  group('ProfileBundleCodec.encode', () {
    test('returns a non-empty byte array', () {
      final bytes = ProfileBundleCodec.encode(completeProfile, fakePhoto);
      expect(bytes, isNotEmpty);
    });

    test('round-trip recovers the original profile fields', () {
      final bytes = ProfileBundleCodec.encode(completeProfile, fakePhoto);
      final bundle = ProfileBundleCodec.decode(bytes);
      expect(bundle.profile.name, equals('Alice'));
      expect(bundle.profile.bio, equals('Hey there'));
    });

    test('round-trip recovers the original photo bytes', () {
      final bytes = ProfileBundleCodec.encode(completeProfile, fakePhoto);
      final bundle = ProfileBundleCodec.decode(bytes);
      expect(bundle.photoBytes, equals(fakePhoto));
    });

    test('throws when total payload exceeds 15KB', () {
      final bigPhoto = Uint8List(16 * 1024); // 16KB — over the limit
      expect(
        () => ProfileBundleCodec.encode(completeProfile, bigPhoto),
        throwsA(isA<ProfileBundleTooLargeException>()),
      );
    });

    test('total payload stays within 15KB for a typical profile', () {
      final bytes = ProfileBundleCodec.encode(completeProfile, fakePhoto);
      expect(bytes.length, lessThanOrEqualTo(15 * 1024));
    });
  });

  group('ProfileBundleCodec.decode', () {
    test('throws on an empty byte array', () {
      expect(
        () => ProfileBundleCodec.decode(Uint8List(0)),
        throwsA(isA<ProfileBundleMalformedException>()),
      );
    });

    test('throws when header is too short', () {
      expect(
        () => ProfileBundleCodec.decode(Uint8List(3)), // needs at least 4
        throwsA(isA<ProfileBundleMalformedException>()),
      );
    });

    test('throws when JSON length field exceeds available bytes', () {
      // Header says JSON is 9999 bytes but payload is only 4 bytes total.
      final bad = ByteData(4)..setUint32(0, 9999);
      expect(
        () => ProfileBundleCodec.decode(bad.buffer.asUint8List()),
        throwsA(isA<ProfileBundleMalformedException>()),
      );
    });

    test('throws when JSON is invalid', () {
      final badJson = 'not json at all';
      final jsonBytes = badJson.codeUnits;
      final header = ByteData(4)..setUint32(0, jsonBytes.length);
      final payload = Uint8List.fromList([
        ...header.buffer.asUint8List(),
        ...jsonBytes,
        0, // at least 1 image byte so image section exists
      ]);
      expect(
        () => ProfileBundleCodec.decode(payload),
        throwsA(isA<ProfileBundleMalformedException>()),
      );
    });
  });
}
