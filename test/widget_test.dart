import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echotv/main.dart';

void main() {
  testWidgets('EchoTV smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: EchoTVApp()));

    // Verify that EchoTV is rendered.
    expect(find.text('ECHOTV'), findsOneWidget);
  });
}