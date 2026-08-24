import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../data/repositories/post_repository.dart';
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final descriptionController = TextEditingController();

  File? selectedImage;

  final picker = ImagePicker();
   final repository = PostRepository();
  String activity = "Tree Plantation";

  final activities = [
    "Tree Plantation",
    "Recycling",
    "Cycling",
    "Walk",
    "Cleanliness Drive",
    "Water Conservation",
  ];

  Future<void> pickImage() async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Eco Post"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: selectedImage == null
                    ? const Center(
                        child: Icon(
                          Icons.add_a_photo,
                          size: 60,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: activity,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Activity",
              ),
              items: activities
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    activity = value;
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Description",
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {

  if (selectedImage == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please select an image"),
      ),
    );
    return;
  }

  try {

    final formData = FormData.fromMap({

      "description": descriptionController.text,

      "activity": activity,

      "image": await MultipartFile.fromFile(
        selectedImage!.path,
        filename: selectedImage!.path.split("/").last,
      ),

    });

    await repository.createPost(formData);

    if (mounted) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Post uploaded successfully 🌱"),
        ),
      );

      Navigator.pop(context);
    }

  } catch (e) {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
      ),
    );

  }

},
                child: const Text("Post 🌱"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}