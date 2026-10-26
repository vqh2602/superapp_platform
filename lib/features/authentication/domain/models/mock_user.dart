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
