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


  Future<void> sendOtp(String phone) async {

    try {

      state = state.copyWith(
        isLoading: true,
        error: null,
      );


      await repository.sendOtp(phone);


      state = state.copyWith(
        isLoading: false,
      );


    } catch(e) {

      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );

    }

  }


Future<LoginResponse?> verifyOtp(
  String phone,
  String otp,
) async {

  print("🔥 VERIFY OTP FUNCTION CALLED");
  print("PHONE: $phone");
  print("OTP: $otp");

  try {

    state = state.copyWith(
      isLoading: true,
    );


    print("🔥 CALLING REPOSITORY");


    final result =
        await repository.verifyOtp(
          phone,
          otp,
        );


    


    final token = result.token;
final user = result.user;


    await StorageService.saveToken(token);
     
     SocketService.instance.connect(user.id);
        
    state = AuthState(
      user: user,
    );


    return LoginResponse(
  token: token,
  user: user,
  isNewUser: result.isNewUser,
);


  } catch(e) {

    print("❌ VERIFY ERROR: $e");


    state = AuthState(
      error: e.toString(),
    );


    return null;

  }

}


  Future<void> logout() async {

    await StorageService.clear();

    state = AuthState();

  }

}



final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(() {

  return AuthNotifier();

});