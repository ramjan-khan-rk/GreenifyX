import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import 'otp_screen.dart';


class LoginScreen extends ConsumerStatefulWidget {

  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() =>
      _LoginScreenState();

}


class _LoginScreenState
    extends ConsumerState<LoginScreen> {


  final phoneController = TextEditingController();


  @override
  Widget build(BuildContext context) {


    final authState = ref.watch(authProvider);


    ref.listen(authProvider, (previous, next) {

      if(next.error != null){

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(next.error!),
          ),
        );

      }

    });


    return Scaffold(

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(24),

          child: Column(

            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [


              const Icon(
                Icons.eco,
                size: 90,
                color: Color(0xFF2E7D32),
              ),


              const SizedBox(height: 20),


              const Text(
                "Welcome to GreenifyX",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),


              const SizedBox(height: 10),


              const Text(
                "Make every action count 🌱",
                style: TextStyle(
                  fontSize: 16,
                ),
              ),


              const SizedBox(height: 40),


              TextField(

                controller: phoneController,

                keyboardType:
                    TextInputType.phone,

                decoration:
                    const InputDecoration(

                  prefixText: "+91 ",

                  labelText:
                      "Phone Number",

                  border:
                      OutlineInputBorder(),

                ),

              ),


              const SizedBox(height: 20),



              SizedBox(

                width: double.infinity,

                height: 50,

                child: ElevatedButton(


                  onPressed:
                      authState.isLoading
                      ? null
                      : () async {


                    final phone =
                        phoneController.text.trim();


                    await ref
                        .read(authProvider.notifier)
                        .sendOtp(phone);



                    if(context.mounted){

                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder:
                              (_) =>
                              OtpScreen(
                                phone: phone,
                              ),

                        ),

                      );

                    }


                  },


                  child:

                  authState.isLoading

                  ?

                  const CircularProgressIndicator()

                  :

                  const Text(
                    "Send OTP",
                  ),


                ),

              )


            ],

          ),

        ),

      ),

    );

  }

}