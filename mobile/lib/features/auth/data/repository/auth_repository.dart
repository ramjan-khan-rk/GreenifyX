import '../../domain/models/user_model.dart';
import '../../domain/models/login_response.dart';
import '../api/auth_api.dart';


class AuthRepository {

  final AuthApi _api = AuthApi();


  Future<void> sendOtp(String phone) async {

    await _api.sendOtp(phone);

  }



  Future<LoginResponse> verifyOtp(
    String phone,
    String otp,
  ) async {


    final response =
        await _api.verifyOtp(
          phone,
          otp,
        );


    final String token =
        response.data["token"] as String;



    final user =
        UserModel.fromJson(
          response.data["user"]
              as Map<String, dynamic>,
        );



    final bool isNewUser =
        response.data["isNewUser"] ?? false;



    return LoginResponse(

      token: token,

      user: user,

      isNewUser: isNewUser,

    );

  }

}