import 'package:flutter_test/flutter_test.dart';
import 'package:greenifyx/core/utils/phone.dart';

void main() {
  test("new numbers default to +971", () {
    expect(withDefaultCountryCode("501234567"), "+971501234567");
    expect(withDefaultCountryCode("+971501234567"), "+971501234567");
  });

  test("explicit +91 is preserved", () {
    expect(withDefaultCountryCode("+919876543210"), "+919876543210");
  });
}
