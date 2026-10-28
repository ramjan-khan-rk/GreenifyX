import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/auth_repository.dart';
import '../../domain/models/user_model.dart';
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

  Future<bool> sendOtp(
    String phone, {
    String purpose = "register",
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await repository.sendOtp(phone, purpose: purpose);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _errorMessage(e),
      );
      return false;
    }
  }

  Future<bool> verifyOtp(
    String phone,
    String otp, {
    String purpose = "register",
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await repository.verifyOtp(phone, otp, purpose: purpose);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(error: _errorMessage(e));
      return false;
    }
  }

  Future<LoginResponse?> setPassword(
    String phone,
    String password, {
    String purpose = "register",
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final result = await repository.setPassword(
        phone,
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
    String phone,
    String password,
  ) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final result = await repository.login(phone, password);
      await _persistSession(result);
      return result;
    } catch (e) {
      state = AuthState(error: _errorMessage(e));
      return null;
    }
  }

  Future<void> _persistSession(LoginResponse result) async {
    await StorageService.saveToken(result.token);
    SocketService.instance.connect(result.user.id);
    state = AuthState(user: result.user);
  }

  Future<void> logout() async {
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
