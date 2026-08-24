import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/comment_provider.dart';

class CommentBottomSheet extends ConsumerStatefulWidget {
  final String postId;

  const CommentBottomSheet({
    super.key,
    required this.postId,
  });

  @override
  ConsumerState<CommentBottomSheet> createState() =>
      _CommentBottomSheetState();
}

class _CommentBottomSheetState
    extends ConsumerState<CommentBottomSheet> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments =
        ref.watch(commentProvider(widget.postId));

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .75,

        child: Column(
          children: [
            const SizedBox(height: 12),

            const Text(
              "Comments",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(),

            Expanded(
              child: comments.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text("No comments yet"),
                    );
                  }

                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, index) {
                      final comment = list[index];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              comment.profileImage != null &&
                                      comment.profileImage!.isNotEmpty
                                  ? NetworkImage(
                                      "http://10.255.139.39:5000/uploads/${comment.profileImage}",
                                    )
                                  : null,
                          child: comment.profileImage == null ||
                                  comment.profileImage!.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(comment.name),
                        subtitle: Text(comment.text),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, s) =>
                    Center(child: Text(e.toString())),
              ),
            ),

            const Divider(),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: "Write a comment...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.green,
                    ),
                    onPressed: () async {
                      final text =
                          controller.text.trim();

                      if (text.isEmpty) return;

                      await ref
                          .read(
                            commentRepositoryProvider,
                          )
                          .addComment(
                            widget.postId,
                            text,
                          );

                      controller.clear();

                      ref.invalidate(
                        commentProvider(widget.postId),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}