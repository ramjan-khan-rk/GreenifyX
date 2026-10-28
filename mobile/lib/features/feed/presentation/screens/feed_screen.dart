import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/media_url.dart';
import '../../application/providers/feed_provider.dart';
import '../../../comment/presentation/widgets/comment_bottom_sheet.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Community Feed 🌱"),
      ),
      body: feed.when(
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(
              child: Text("No posts yet"),
            );
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundImage: post.profileImage != null &&
                                post.profileImage!.isNotEmpty
                            ? NetworkImage(
                                resolveMediaUrl(post.profileImage) ?? "",
                              )
                            : null,
                        child: post.profileImage == null ||
                                post.profileImage!.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(post.name),
                      subtitle: Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          post.activity,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        resolveMediaUrl(post.image) ?? "",
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.cover,
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(post.description),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          post.isVerified
                              ? "🌱 ${post.ecoPoints} Eco Points"
                              : "🌱 ${post.ecoPoints} Eco Points (unverified)",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    OverflowBar(
                      alignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(feedRepositoryProvider)
                                  .toggleLike(post.id);

                              ref.invalidate(feedProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString()),
                                  ),
                                );
                              }
                            }
                          },
                          icon: Icon(
  post.isLiked
      ? Icons.favorite
      : Icons.favorite_border,
  color: post.isLiked
      ? Colors.red
      : null,
),
                          label: Text("${post.likes}"),
                        ),
                        
TextButton.icon(
  onPressed: () {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentBottomSheet(
        postId: post.id,
      ),
    );
  },
  icon: const Icon(Icons.comment),
  label: Text("${post.comments}"),
),         ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, s) => Center(
          child: Text(e.toString()),
        ),
      ),
    );
  }
}