import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_bundle_codec.dart';
import 'profile_model.dart';

typedef PhotoCompressor = Future<Uint8List> Function(Uint8List bytes);

Future<Uint8List> _compressToThumbnail(Uint8List bytes) async {
  return FlutterImageCompress.compressWithList(
    bytes,
    minWidth: 96,
    minHeight: 96,
    quality: 70,
    format: CompressFormat.jpeg,
  );
}

class ProfileRepository {
  ProfileRepository(this._prefs, this._photoFile, {PhotoCompressor? compressor})
    : _compress = compressor ?? _identity;

  static Future<Uint8List> _identity(Uint8List b) async => b;

  final SharedPreferences _prefs;
  final File _photoFile;
  final PhotoCompressor _compress;

  static const _kName = 'profile.name';
  static const _kBio = 'profile.bio';
  static const _kGender = 'profile.gender';
  static const _kAge = 'profile.age';
  static const _kHeight = 'profile.height';
  static const _kBodyShape = 'profile.bodyShape';
  static const _kHairColour = 'profile.hairColour';

  static Future<ProfileRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    return ProfileRepository(
      prefs,
      File('${dir.path}/profile_photo.jpg'),
      compressor: _compressToThumbnail,
    );
  }

  Future<void> save(ProfileBundle bundle) async {
    final p = bundle.profile;
    await _prefs.setString(_kName, p.name);
    await _prefs.setString(_kBio, p.bio);
    if (p.gender != null) {
      await _prefs.setString(_kGender, p.gender!);
    } else {
      await _prefs.remove(_kGender);
    }
    if (p.age != null) {
      await _prefs.setInt(_kAge, p.age!);
    } else {
      await _prefs.remove(_kAge);
    }
    if (p.height != null) {
      await _prefs.setInt(_kHeight, p.height!);
    } else {
      await _prefs.remove(_kHeight);
    }
    if (p.bodyShape != null) {
      await _prefs.setString(_kBodyShape, p.bodyShape!);
    } else {
      await _prefs.remove(_kBodyShape);
    }
    if (p.hairColour != null) {
      await _prefs.setString(_kHairColour, p.hairColour!);
    } else {
      await _prefs.remove(_kHairColour);
    }

    if (bundle.photoBytes.isNotEmpty) {
      final compressed = await _compress(bundle.photoBytes);
      await _photoFile.writeAsBytes(compressed);
    } else if (await _photoFile.exists()) {
      await _photoFile.delete();
    }
  }

  Future<ProfileBundle?> load() async {
    final name = _prefs.getString(_kName);
    final bio = _prefs.getString(_kBio);
    if (name == null || bio == null) return null;

    Uint8List photoBytes = Uint8List(0);
    if (await _photoFile.exists()) {
      photoBytes = Uint8List.fromList(await _photoFile.readAsBytes());
    }

    return ProfileBundle(
      profile: ProfileModel(
        name: name,
        bio: bio,
        photoUrl: photoBytes.isNotEmpty ? 'local' : null,
        gender: _prefs.getString(_kGender),
        age: _prefs.getInt(_kAge),
        height: _prefs.getInt(_kHeight),
        bodyShape: _prefs.getString(_kBodyShape),
        hairColour: _prefs.getString(_kHairColour),
      ),
      photoBytes: photoBytes,
    );
  }
}
