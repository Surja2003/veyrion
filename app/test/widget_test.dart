import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:darm_scanner/main.dart';

void main() {
  testWidgets('App boots without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DarmApp());
    await tester.pump();
    expect(find.byType(DarmApp), findsOneWidget);
  });
}
