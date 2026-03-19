import 'package:flutter_test/flutter_test.dart';
import 'package:nestvia/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const NestviaApp());
    expect(find.byType(NestviaApp), findsOneWidget);
  });
}
