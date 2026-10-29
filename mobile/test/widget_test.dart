import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/app.dart';

void main() {
  testWidgets('App smoke test builds MyApp without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
  });
}
