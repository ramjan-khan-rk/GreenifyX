import 'user_model.dart';

class LoginResponse {
  final String token;
  final UserModel user;
  final bool isNewUser;

  const LoginResponse({
    required this.token,
    required this.user,
    required this.isNewUser,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json["token"] ?? "",
      isNewUser: json["isNewUser"] ?? false,
      user: UserModel.fromJson(json["user"] ?? {}),
    );
  }
}