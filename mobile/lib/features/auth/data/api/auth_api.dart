import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';

class AuthApi {
  Future<Response> sendOtp(
    String phone, {
    String purpose = "register",
  }) async {
    return await ApiService.dio.post(
      "/auth/send-otp",
      data: {
        "phone": phone,
        "purpose": purpose,
      },
    );
  }

  Future<Response> verifyOtp(
    String phone,
    String otp, {
    String purpose = "register",
  }) async {
    return await ApiService.dio.post(
      "/auth/verify-otp",
      data: {
        "phone": phone,
        "otp": otp,
        "purpose": purpose,
      },
    );
  }

  Future<Response> setPassword(
    String phone,
    String password, {
    String purpose = "register",
  }) async {
    return await ApiService.dio.post(
      "/auth/set-password",
      data: {
        "phone": phone,
        "password": password,
        "purpose": purpose,
      },
    );
  }

  Future<Response> login(
    String phone,
    String password,
  ) async {
    return await ApiService.dio.post(
      "/auth/login",
      data: {
        "phone": phone,
        "password": password,
      },
    );
  }
}
