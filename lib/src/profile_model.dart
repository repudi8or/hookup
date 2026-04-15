class ProfileModel {
  const ProfileModel({
    required this.name,
    required this.bio,
    required this.photoUrl,
  });

  final String name;
  final String bio;
  final String? photoUrl;

  bool get isComplete => name.isNotEmpty && bio.isNotEmpty && photoUrl != null;

  ProfileModel copyWith({
    String? name,
    String? bio,
    String? photoUrl,
    bool clearPhotoUrl = false,
  }) {
    return ProfileModel(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
    );
  }
}
