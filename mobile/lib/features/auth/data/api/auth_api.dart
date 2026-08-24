import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';

class AuthApi {
  Future<Response> sendOtp(String phone) async {
    return await ApiService.dio.post(
      "/auth/send-otp",
      data: {
        "phone": phone,
      },
    );
  }

  Future<Response> verifyOtp(
    String phone,
    String otp,
  ) async {
    return await ApiService.dio.post(
      "/auth/verify-otp",
      data: {
        "phone": phone,
        "otp": otp,
      },
    );
  }
}