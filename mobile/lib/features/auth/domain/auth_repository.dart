import 'package:controle_ds/features/auth/domain/user.dart';

abstract interface class AuthRepository {
  Future<User> login(String email, String password);

  Future<User> register(
    String name,
    String email,
    String password,
    bool acceptedTerms,
  );

  Future<User> refresh(String refreshToken);

  Future<void> logout();

  Future<void> forgotPassword(String email);

  Future<void> resetPassword(String token, String newPassword);
}
