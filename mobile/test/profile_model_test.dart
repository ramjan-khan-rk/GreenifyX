import 'package:flutter_test/flutter_test.dart';
import 'package:greenifyx/features/profile/domain/models/profile_model.dart';

void main() {
  test("profile model reads badges", () {
    final user = ProfileModel.fromJson({
      "_id": "u1",
      "name": "Sam",
      "bio": "",
      "profileImage": "",
      "email": "sam@example.com",
      "ecoPoints": 110,
      "streak": 3,
      "level": 2,
      "friendsCount": 1,
      "badges": ["first_verified", "century"],
    });
    expect(user.badges, ["first_verified", "century"]);
    expect(user.ecoPoints, 110);
  });
}
