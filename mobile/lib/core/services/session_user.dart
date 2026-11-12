/// The signed-in member, for widgets that live outside Riverpod.
/// Kept in sync by the main navigation screen.
class SessionUser {
  SessionUser._();
  static String id = "";
  static String name = "";
  static String profileImage = "";

  static void update({required String id, String name = "", String profileImage = ""}) {
    SessionUser.id = id;
    if (name.isNotEmpty) SessionUser.name = name;
    if (profileImage.isNotEmpty) SessionUser.profileImage = profileImage;
  }
}
