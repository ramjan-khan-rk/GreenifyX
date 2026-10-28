import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenifyx/core/widgets/points_status_chip.dart';

void main() {
  testWidgets("renders self-reported copy", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PointsStatusChip(ecoPoints: 15, isVerified: false),
        ),
      ),
    );
    expect(find.text("15 Eco Points · self-reported"), findsOneWidget);
  });
}
