import 'package:flutter_test/flutter_test.dart';
import 'package:buzza_admin/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BuzzaAdminApp());
    expect(find.text('Buzza Admin'), findsOneWidget);
  });
}
