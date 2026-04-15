import 'dart:convert';
import 'dart:typed_data';

import 'profile_model.dart';

/// Maximum total bytes allowed for an encoded profile bundle (~15KB).
const int kMaxProfileBundleBytes = 15 * 1024;

/// Holds a decoded profile bundle: the profile data and the raw photo bytes.
class ProfileBundle {
  const ProfileBundle({required this.profile, required this.photoBytes});

  final ProfileModel profile;
  final Uint8List photoBytes;
}

/// Thrown when an encoded bundle would exceed [kMaxProfileBundleBytes].
class ProfileBundleTooLargeException implements Exception {
  const ProfileBundleTooLargeException(this.actualBytes);
  final int actualBytes;

  @override
  String toString() =>
      'ProfileBundleTooLargeException: payload is $actualBytes bytes '
      '(limit $kMaxProfileBundleBytes)';
}

/// Thrown when a byte array cannot be decoded into a [ProfileBundle].
class ProfileBundleMalformedException implements Exception {
  const ProfileBundleMalformedException(this.reason);
  final String reason;

  @override
  String toString() => 'ProfileBundleMalformedException: $reason';
}

/// Encodes and decodes profile bundles for transmission over Nearby Connections.
///
/// Binary layout:
///   [0..3]              json_length — big-endian uint32
///   [4..4+json_length)  UTF-8 JSON: {"name":"...","bio":"..."}
///   [4+json_length..]   raw photo bytes (JPEG)
class ProfileBundleCodec {
  ProfileBundleCodec._();

  /// Encodes [profile] and [photoBytes] into a single byte payload.
  ///
  /// Throws [ProfileBundleTooLargeException] if the result exceeds
  /// [kMaxProfileBundleBytes].
  static Uint8List encode(ProfileModel profile, Uint8List photoBytes) {
    final jsonBytes = utf8.encode(
      jsonEncode({
        'name': profile.name,
        'bio': profile.bio,
        if (profile.gender != null) 'gender': profile.gender,
        if (profile.age != null) 'age': profile.age,
        if (profile.height != null) 'height': profile.height,
        if (profile.bodyShape != null) 'bodyShape': profile.bodyShape,
        if (profile.hairColour != null) 'hairColour': profile.hairColour,
      }),
    );

    final totalLength = 4 + jsonBytes.length + photoBytes.length;
    if (totalLength > kMaxProfileBundleBytes) {
      throw ProfileBundleTooLargeException(totalLength);
    }

    final buffer = ByteData(totalLength);
    buffer.setUint32(0, jsonBytes.length);

    final out = buffer.buffer.asUint8List();
    out.setRange(4, 4 + jsonBytes.length, jsonBytes);
    out.setRange(4 + jsonBytes.length, totalLength, photoBytes);

    return out;
  }

  /// Decodes [bytes] into a [ProfileBundle].
  ///
  /// Throws [ProfileBundleMalformedException] if the bytes are invalid.
  static ProfileBundle decode(Uint8List bytes) {
    if (bytes.length < 4) {
      throw const ProfileBundleMalformedException(
        'payload too short to contain header',
      );
    }

    final jsonLength = ByteData.sublistView(bytes).getUint32(0);
    if (4 + jsonLength > bytes.length) {
      throw const ProfileBundleMalformedException(
        'json_length field exceeds available bytes',
      );
    }

    final Map<String, dynamic> json;
    try {
      json =
          jsonDecode(utf8.decode(bytes.sublist(4, 4 + jsonLength)))
              as Map<String, dynamic>;
    } catch (_) {
      throw const ProfileBundleMalformedException('invalid JSON in payload');
    }

    final name = json['name'];
    final bio = json['bio'];
    if (name is! String || bio is! String) {
      throw const ProfileBundleMalformedException(
        'missing required JSON fields: name, bio',
      );
    }

    final photoBytes = bytes.sublist(4 + jsonLength);

    return ProfileBundle(
      profile: ProfileModel(
        name: name,
        bio: bio,
        photoUrl: null,
        gender: json['gender'] as String?,
        age: json['age'] as int?,
        height: json['height'] as int?,
        bodyShape: json['bodyShape'] as String?,
        hairColour: json['hairColour'] as String?,
      ),
      photoBytes: photoBytes,
    );
  }
}
