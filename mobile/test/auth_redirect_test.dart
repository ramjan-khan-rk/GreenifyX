import 'package:flutter_test/flutter_test.dart';
import 'package:greenifyx/core/session/session_controller.dart';

void main() {
  test("unauthenticated users cannot open home", () {
    expect(
      authRedirect(hasToken: false, location: "/home"),
      "/login",
    );
    expect(
      authRedirect(hasToken: false, location: "/complete-profile"),
      "/login",
    );
  });

  test("splash stays open so restore can run", () {
    expect(authRedirect(hasToken: false, location: "/"), isNull);
    expect(authRedirect(hasToken: true, location: "/"), isNull);
  });

  test("signed-in users skip login and register", () {
    expect(authRedirect(hasToken: true, location: "/login"), "/home");
    expect(authRedirect(hasToken: true, location: "/register"), "/home");
    expect(authRedirect(hasToken: true, location: "/home"), isNull);
  });
}
