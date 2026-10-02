import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fit_odyssey/main.dart';

void main() {
  testWidgets('Fit Odyssey App boots up and displays splash placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FitOdysseyApp(),
      ),
    );

    // Initial pump
    await tester.pumpAndSettle();

    // Verify splash screen placeholder title is visible in both AppBar and body
    expect(find.text('Fit Odyssey Splash'), findsNWidgets(2));
  });
}
