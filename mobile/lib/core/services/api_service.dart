import 'package:dio/dio.dart';

import 'storage_service.dart';

class ApiService {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: "http://10.238.223.39:5000/api",

      connectTimeout: const Duration(seconds: 100),
      receiveTimeout: const Duration(seconds: 10),

      headers: {
        "Content-Type": "application/json",
      },
    ),
  );

  static Future<void> initialize() async {
    dio.interceptors.clear();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();

          if (token != null) {
            options.headers["Authorization"] = "Bearer $token";
          }

          handler.next(options);
        },
      ),
    );
  }
}