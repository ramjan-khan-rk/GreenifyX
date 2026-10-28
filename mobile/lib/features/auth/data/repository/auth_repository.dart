import '../../domain/models/user_model.dart';
import '../../domain/models/login_response.dart';
import '../api/auth_api.dart';

class AuthRepository {
  final AuthApi _api = AuthApi();

  Future<String?> sendOtp(
    String email, {
    String purpose = "register",
  }) async {
    final response = await _api.sendOtp(email, purpose: purpose);
    final data = response.data;
    if (data is Map && data["devOtp"] != null) {
      return data["devOtp"].toString();
    }
    return null;
  }

  Future<void> verifyOtp(
    String email,
    String otp, {
    String purpose = "register",
  }) async {
    await _api.verifyOtp(email, otp, purpose: purpose);
  }

  Future<LoginResponse> setPassword(
    String email,
    String password, {
    String purpose = "register",
  }) async {
    final response = await _api.setPassword(
      email,
      password,
      purpose: purpose,
    );

    return _parseLoginResponse(response.data);
  }

  Future<LoginResponse> login(
    String identifier,
    String password,
  ) async {
    final response = await _api.login(identifier, password);
    return _parseLoginResponse(response.data);
  }

  LoginResponse _parseLoginResponse(dynamic data) {
    final String token = data["token"] as String;
    final user = UserModel.fromJson(
      data["user"] as Map<String, dynamic>,
    );
    final bool isNewUser = data["isNewUser"] ?? false;

    return LoginResponse(
      token: token,
      user: user,
      isNewUser: isNewUser,
    );
  }
}
