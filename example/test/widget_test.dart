import 'package:flutter_ausweisapp_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the example title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('flutter_ausweisapp example'), findsOneWidget);
  });
}
