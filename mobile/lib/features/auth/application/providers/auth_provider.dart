import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../data/repository/auth_repository.dart';
import '../../domain/models/user_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/models/login_response.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/utils/friendly_error.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository repository;

  @override
  AuthState build() {
    repository = ref.read(authRepositoryProvider);
    return AuthState();
  }

  Future<String?> sendOtp(
    String email, {
    String purpose = "register",
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final devOtp = await repository.sendOtp(email, purpose: purpose);
      state = state.copyWith(isLoading: false);
      return devOtp;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _errorMessage(e),
      );
      return null;
    }
  }

  Future<bool> verifyOtp(
    String email,
    String otp, {
    String purpose = "register",
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await repository.verifyOtp(email, otp, purpose: purpose);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(error: _errorMessage(e));
      return false;
    }
  }

  Future<LoginResponse?> setPassword(
    String email,
    String password, {
    String purpose = "register",
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final result = await repository.setPassword(
        email,
        password,
        purpose: purpose,
      );

      await _persistSession(result);
      return result;
    } catch (e) {
      state = AuthState(error: _errorMessage(e));
      return null;
    }
  }

  Future<LoginResponse?> login(
    String identifier,
    String password,
  ) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final result = await repository.login(identifier, password);
      await _persistSession(result);
      return result;
    } catch (e) {
      state = AuthState(error: _errorMessage(e));
      return null;
    }
  }

  Future<void> _persistSession(LoginResponse result) async {
    await StorageService.saveToken(result.token);
    SessionController.instance.setHasToken(true);
    await SocketService.instance.connect(result.user.id);
    state = AuthState(user: result.user);
  }

  Future<UserModel?> restoreSession() async {
    final token = await StorageService.getToken();
    if (token == null || token.isEmpty) {
      SessionController.instance.setHasToken(false);
      return null;
    }

    try {
      final response = await ApiService.dio.get("/users/me");
      final userJson = response.data["user"] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);
      SessionController.instance.setHasToken(true);
      await SocketService.instance.connect(user.id);
      state = AuthState(user: user);
      return user;
    } on DioException catch (e) {
      // Only a rejected token means "log out". A slow or missing network
      // must never sign someone out; the splash screen offers a retry instead.
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403 || code == 404) {
        await StorageService.clear();
        SocketService.instance.disconnect();
        SessionController.instance.setHasToken(false);
        state = AuthState();
        return null;
      }
      rethrow;
    } catch (_) {
      await StorageService.clear();
      SocketService.instance.disconnect();
      SessionController.instance.setHasToken(false);
      state = AuthState();
      return null;
    }
  }

  Future<void> logout() async {
    SocketService.instance.disconnect();
    await StorageService.clear();
    SessionController.instance.setHasToken(false);
    state = AuthState();
  }

  String _errorMessage(Object e) {
    try {
      final dynamic err = e;
      final data = err.response?.data;
      if (data is Map && data["message"] != null) {
        return data["message"].toString();
      }
    } catch (_) {}
    return friendlyError(e);
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
