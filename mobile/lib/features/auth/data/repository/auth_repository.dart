import '../../domain/models/user_model.dart';
import '../../domain/models/login_response.dart';
import '../api/auth_api.dart';

class AuthRepository {
  final AuthApi _api = AuthApi();

  Future<String?> sendOtp(
    String phone, {
    String purpose = "register",
  }) async {
    final response = await _api.sendOtp(phone, purpose: purpose);
    final data = response.data;
    if (data is Map && data["devOtp"] != null) {
      return data["devOtp"].toString();
    }
    return null;
  }

  Future<void> verifyOtp(
    String phone,
    String otp, {
    String purpose = "register",
  }) async {
    await _api.verifyOtp(phone, otp, purpose: purpose);
  }

  Future<LoginResponse> setPassword(
    String phone,
    String password, {
    String purpose = "register",
  }) async {
    final response = await _api.setPassword(
      phone,
      password,
      purpose: purpose,
    );

    return _parseLoginResponse(response.data);
  }

  Future<LoginResponse> login(
    String phone,
    String password,
  ) async {
    final response = await _api.login(phone, password);
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
