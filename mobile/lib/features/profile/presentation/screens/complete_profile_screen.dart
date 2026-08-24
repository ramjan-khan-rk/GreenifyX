import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';


class CompleteProfileScreen extends ConsumerStatefulWidget {

  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();

}


class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {


  final nameController = TextEditingController();

  final bioController = TextEditingController();



  @override
  Widget build(BuildContext context) {

    final state = ref.watch(profileProvider);


    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Complete Profile",
        ),
      ),


      body: SingleChildScrollView(

        padding: const EdgeInsets.all(24),

        child: Column(

          children: [


            const SizedBox(height: 20),


            ProfileAvatar(

              image: state.imageFile,

              onTap: () {

                ref
                .read(profileProvider.notifier)
                .pickImage();

              },

            ),


            const SizedBox(height: 35),



            TextField(

              controller: nameController,

              decoration: const InputDecoration(

                labelText: "Full Name",

                border: OutlineInputBorder(),

              ),

            ),


            const SizedBox(height: 20),



            TextField(

              controller: bioController,

              maxLines: 4,

              maxLength: 150,

              decoration: const InputDecoration(

                labelText: "Bio",

                hintText:
                "Tell something about yourself",

                border: OutlineInputBorder(),

              ),

            ),



            const SizedBox(height: 30),



            SizedBox(

              width: double.infinity,

              height: 52,


              child: ElevatedButton(


                onPressed: state.isLoading

                ? null

                : () async {


                  if(state.imageFile != null &&
                     state.profileImage.isEmpty){

                    await ref
                    .read(profileProvider.notifier)
                    .uploadImage();

                  }



                  final success =
                  await ref
                  .read(profileProvider.notifier)
                  .saveProfile(

                    name:
                    nameController.text.trim(),

                    bio:
                    bioController.text.trim(),

                  );



                  if(success && context.mounted){

                    context.go("/home");

                  }


                },


                child:

                state.isLoading

                ?

                const CircularProgressIndicator()

                :

                const Text(
                  "Save Profile 🌱",
                ),


              ),

            ),


          ],

        ),

      ),

    );

  }

}