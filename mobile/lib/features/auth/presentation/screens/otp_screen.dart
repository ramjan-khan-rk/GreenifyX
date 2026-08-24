import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class OtpScreen extends ConsumerStatefulWidget {

  final String phone;


  const OtpScreen({
    super.key,
    required this.phone,
  });


  @override
  ConsumerState<OtpScreen> createState() =>
      _OtpScreenState();

}



class _OtpScreenState
    extends ConsumerState<OtpScreen>{


  final otpController =
      TextEditingController();



  @override
  Widget build(BuildContext context) {


    final authState =
        ref.watch(authProvider);



    return Scaffold(

      appBar:
          AppBar(
            title:
            const Text(
              "Verify OTP",
            ),
          ),


      body:
      Padding(

        padding:
        const EdgeInsets.all(24),


        child:
        Column(

          mainAxisAlignment:
          MainAxisAlignment.center,


          children: [


            Text(
              "OTP sent to ${widget.phone}",
            ),


            const SizedBox(
              height: 30,
            ),


            TextField(

              controller:
              otpController,


              keyboardType:
              TextInputType.number,


              maxLength:
              4,


              decoration:
              const InputDecoration(

                labelText:
                "Enter OTP",

                border:
                OutlineInputBorder(),

              ),

            ),


            const SizedBox(
              height: 20,
            ),



            SizedBox(

              width:
              double.infinity,


              height:
              50,


              child:
              ElevatedButton(


                onPressed:
                authState.isLoading
                ?

                null

                :

                () async{


                 final result =
await ref
    .read(authProvider.notifier)
    .verifyOtp(
      widget.phone,
      otpController.text.trim(),
    );


                 if(result != null &&
    context.mounted){
                    ScaffoldMessenger
                        .of(context)
                        .showSnackBar(

                      const SnackBar(

                        content:
                        Text(
                          "Login Successful 🌱",
                        ),

                      ),
                        

                    );
                    if(result.isNewUser == true){

  context.go("/complete-profile");

}else{

  context.go("/home");

}

                  }


                },


                child:
                authState.isLoading

                ?

                const CircularProgressIndicator()

                :

                const Text(
                  "Verify OTP",
                ),

              ),

            )

          ],

        ),

      ),

    );

  }

}