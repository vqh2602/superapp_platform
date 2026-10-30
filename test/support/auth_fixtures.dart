import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_repository.dart';
import 'package:superapp_platform/features/authentication/domain/models/auth_session.dart';
import 'package:superapp_platform/features/authentication/domain/models/mock_user.dart';

class TestUsers {
  static const userA = MockUser(
    id: 'user_001',
    name: 'Nguyễn Văn A',
    phone: '0900000001',
    role: 'customer',
    email: 'a@example.test',
  );
  static const userB = MockUser(
    id: 'user_002',
    name: 'Trần Thị B',
    phone: '0900000002',
    role: 'customer',
    email: 'b@example.test',
  );
}

class TestAuthRepository extends MockAuthRepository {
  TestAuthRepository()
    : super(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/logout'))
            return http.Response('{}', 200);
          final id = jsonDecode(request.body)['email'];
          final user = id == TestUsers.userB.id
              ? TestUsers.userB
              : TestUsers.userA;
          return http.Response(
            jsonEncode({
              'user': user.toFullProfileJson(),
              'accessToken': 'fixture-access-${user.id}',
              'refreshToken': 'fixture-refresh',
              'expiresIn': 3600,
            }),
            200, headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
  @override
  Future<AuthSession> login(String emailOrUserId, [String? password]) =>
      super.login(emailOrUserId, password ?? 'fixture-password');
}
