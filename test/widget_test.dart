import 'package:flutter_test/flutter_test.dart';
import 'package:dogtopia/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DogtopiaApp());
    expect(find.byType(DogtopiaApp), findsOneWidget);
  });
}
