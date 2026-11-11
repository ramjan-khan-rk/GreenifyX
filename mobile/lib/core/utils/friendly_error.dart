import 'package:dio/dio.dart';

/// Turns API/network failures into a sentence a user can act on,
/// instead of showing raw exception text.
String friendlyError(Object error, {String fallback = "Something went wrong. Please try again."}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data["message"] is String && (data["message"] as String).isNotEmpty) {
      return data["message"] as String;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return "The server is taking too long. Please try again.";
      case DioExceptionType.connectionError:
        return "No internet connection.";
      default:
        break;
    }
  }
  return fallback;
}
