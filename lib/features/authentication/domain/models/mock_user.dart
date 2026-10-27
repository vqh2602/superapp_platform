/// Mock user representation for the Super App platform.
class MockUser {
  final String id;
  final String name;
  final String phone;
  final String role;
  final String email;
  final String? avatarUrl;

  const MockUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.email,
    this.avatarUrl,
  });

  static const MockUser userA = MockUser(
    id: 'user_001',
    name: 'Nguyễn Văn A',
    phone: '0900000001',
    role: 'customer',
    email: 'nguyenvana@example.com',
    avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150',
  );

  static const MockUser userB = MockUser(
    id: 'user_002',
    name: 'Trần Thị B',
    phone: '0900000002',
    role: 'customer',
    email: 'tranthib@example.com',
    avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150',
  );

  static const List<MockUser> demoUsers = [userA, userB];

  factory MockUser.fromBackendJson(Map<String, dynamic> json) {
    return MockUser(
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
