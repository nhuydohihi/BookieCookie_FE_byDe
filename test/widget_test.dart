import 'package:flutter_test/flutter_test.dart';

import 'package:boocoo/main.dart';

void main() {
  testWidgets('login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const BookieCookieApp());

    expect(find.text('Login Now'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
