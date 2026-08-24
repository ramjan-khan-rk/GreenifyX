import 'dart:io';

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {

  final File? image;
  final VoidCallback onTap;

  const ProfileAvatar({
    super.key,
    required this.image,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: Stack(

        children: [

          CircleAvatar(

            radius: 55,

            backgroundImage:
                image != null
                ? FileImage(image!)
                : null,

            child: image == null
                ? const Icon(
                    Icons.person,
                    size: 55,
                  )
                : null,

          ),


          Positioned(

            bottom: 0,

            right: 0,

            child: Container(

              padding: const EdgeInsets.all(8),

              decoration: BoxDecoration(

                color:
                Theme.of(context)
                    .colorScheme
                    .primary,

                shape: BoxShape.circle,

              ),

              child: const Icon(

                Icons.camera_alt,

                color: Colors.white,

                size: 18,

              ),

            ),

          ),

        ],

      ),

    );

  }

}