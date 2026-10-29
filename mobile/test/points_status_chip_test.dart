import 'package:flutter_test/flutter_test.dart';
import 'package:greenifyx/core/widgets/points_status_chip.dart';
import 'package:greenifyx/features/feed/domain/models/feed_model.dart';

void main() {
  test("chip labels distinguish verified vs self-reported", () {
    expect(
      PointsStatusChip.label(ecoPoints: 20, isVerified: false),
      "20 Eco Points · self-reported",
    );
    expect(
      PointsStatusChip.label(ecoPoints: 50, isVerified: true),
      "50 Eco Points · verified",
    );
  });

  test("feed model defaults unverified points status", () {
    final post = FeedModel.fromJson({
      "_id": "p1",
      "user": {"_id": "u1", "name": "Sam"},
      "image": "https://example.com/p.jpg",
      "description": "",
      "activity": "Recycling",
      "ecoPoints": 20,
      "likesCount": 0,
      "commentsCount": 0,
      "isLiked": false,
      "isVerified": false,
    });
    expect(post.pointsStatus, "unverified_self_reported");
    expect(post.isVerified, false);
  });
}
