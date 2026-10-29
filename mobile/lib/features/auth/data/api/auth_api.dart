import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/utils/phone.dart';

class AuthApi {
  Map<String, dynamic> _otpPayload(
    String email, {
    required String purpose,
    String? otp,
    String? password,
  }) {
    final data = <String, dynamic>{
      "email": email.trim().toLowerCase(),
      "purpose": purpose,
    };
    if (otp != null) {
      data["otp"] = otp;
    }
    if (password != null) {
      data["password"] = password;
    }
    return data;
  }

  Future<Response> sendOtp(
    String email, {
    String purpose = "register",
  }) {
    return ApiService.dio.post(
      "/auth/send-otp",
      data: _otpPayload(email, purpose: purpose),
    );
  }

  Future<Response> verifyOtp(
    String email,
    String otp, {
    String purpose = "register",
  }) {
    return ApiService.dio.post(
      "/auth/verify-otp",
      data: _otpPayload(email, purpose: purpose, otp: otp),
    );
  }

  Future<Response> setPassword(
    String email,
    String password, {
    String purpose = "register",
  }) {
    return ApiService.dio.post(
      "/auth/set-password",
      data: _otpPayload(email, purpose: purpose, password: password),
    );
  }

  Future<Response> login(String identifier, String password) {
    final trimmed = identifier.trim();
    final data = <String, dynamic>{"password": password};
    if (trimmed.contains("@")) {
      data["email"] = trimmed;
    } else {
      data["phone"] = withDefaultCountryCode(trimmed);
    }

    return ApiService.dio.post("/auth/login", data: data);
  }
}
