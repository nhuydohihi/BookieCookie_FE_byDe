class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.bio,
  });

  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? bio;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];

    return UserModel(
      id: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }
}
