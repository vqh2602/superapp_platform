class UserProfileModel {
  final String id;
  final String name;
  final String phone;
  final String role;
  final String email;
  final String? avatarUrl;

  const UserProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.email,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'role': role,
    'email': email,
    'avatarUrl': avatarUrl,
  };
}
