import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fit_odyssey/main.dart';

void main() {
  testWidgets('Fit Odyssey App boots up and displays Home Dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FitOdysseyApp(),
      ),
    );

    // Initial pump
    await tester.pumpAndSettle();

    // Verify the Home Dashboard is visible:
    // - Greeting text (Good Morning/Afternoon/Evening) is present
    // - Bottom navigation bar with Home tab is present
    expect(find.text('Odyssey Athlete'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
