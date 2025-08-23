class UserModel {
  final int id;
  final String name;
  final String? email;
  final String? profileImageUrl;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) {
    return UserModel(
      id: j['id'] ?? 0,
      name: j['name'] ?? '',
      email: j['email'],
      profileImageUrl: j['profile_image_url'] ?? j['profile_image'],
    );
  }

  @override
  String toString() => 'UserModel(id:$id, name:$name)';
}
