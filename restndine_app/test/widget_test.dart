import 'package:flutter_test/flutter_test.dart';
import 'package:restndine_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RestNDineApp());
    expect(find.byType(RestNDineApp), findsOneWidget);
  });
}
