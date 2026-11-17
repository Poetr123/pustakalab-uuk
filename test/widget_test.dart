import 'package:flutter_test/flutter_test.dart';
import 'package:pustakalab/main.dart';

void main() {
  testWidgets('PustakaLab dapat dijalankan', (WidgetTester tester) async {
    await tester.pumpWidget(const PustakaLab());

    expect(find.byType(PustakaLab), findsOneWidget);
    expect(find.text('PustakaLab'), findsOneWidget);
  });
}
