import 'package:dnd_auto/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders shell', (WidgetTester tester) async {
    await tester.pumpWidget(const AutoDndApp());

    expect(find.text('Auto DND'), findsOneWidget);
  });
}
