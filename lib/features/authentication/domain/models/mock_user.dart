/// Backend user representation for the Super App platform.
class PlatformUser {
  final String id;
  final String name;
  final String phone;
  final String role;
  final String email;
  final String? avatarUrl;

  const PlatformUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.email,
    this.avatarUrl,
  });

  factory PlatformUser.fromBackendJson(Map<String, dynamic> json) {
    return PlatformUser(
      id: json['id'] as String? ?? '',
      name: (json['displayName'] ?? json['name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      role: (json['role'] ?? 'customer') as String,
      email: (json['email'] ?? '') as String,
      avatarUrl: (json['avatarUrl'] as String?)?.isNotEmpty == true
          ? json['avatarUrl'] as String
          : null,
    );
  }

  Map<String, dynamic> toBasicInfoJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
  };

  Map<String, dynamic> toFullProfileJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'role': role,
    'email': email,
    'avatarUrl': avatarUrl,
  };
}

typedef MockUser = PlatformUser;
