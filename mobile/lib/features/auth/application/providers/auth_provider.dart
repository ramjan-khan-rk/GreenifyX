import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/auth_repository.dart';
import '../../domain/models/user_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/models/login_response.dart';
import '../../../../core/services/socket_service.dart';

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
    await SocketService.instance.connect(result.user.id);
    state = AuthState(user: result.user);
  }

  Future<UserModel?> restoreSession() async {
    final token = await StorageService.getToken();
    if (token == null) return null;

    try {
      final response = await ApiService.dio.get("/users/me");
      final userJson = response.data["user"] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);
      await SocketService.instance.connect(user.id);
      state = AuthState(user: user);
      return user;
    } catch (_) {
      await StorageService.clear();
      SocketService.instance.disconnect();
      state = AuthState();
      return null;
    }
  }

  Future<void> logout() async {
    SocketService.instance.disconnect();
    await StorageService.clear();
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
    return e.toString();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
