class ProfileModel {
  const ProfileModel({
    required this.name,
    required this.bio,
    required this.photoUrl,
    this.gender,
    this.age,
    this.height,
    this.bodyShape,
    this.hairColour,
  });

  final String name;
  final String bio;
  final String? photoUrl;

  // Optional profile context — not required for broadcast to be unlocked.
  final String? gender;
  final int? age;
  final int? height; // centimetres
  final String? bodyShape;
  final String? hairColour;

  bool get isComplete => name.isNotEmpty && bio.isNotEmpty && photoUrl != null;

  ProfileModel copyWith({
    String? name,
    String? bio,
    String? photoUrl,
    bool clearPhotoUrl = false,
    String? gender,
    int? age,
    int? height,
    String? bodyShape,
    String? hairColour,
  }) {
    return ProfileModel(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      bodyShape: bodyShape ?? this.bodyShape,
      hairColour: hairColour ?? this.hairColour,
    );
  }
}
