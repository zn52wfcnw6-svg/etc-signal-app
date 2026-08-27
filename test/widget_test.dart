import 'package:flutter_test/flutter_test.dart';
import 'package:etc_signal_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EthSignalApp());
    expect(find.text('ETC永续信号监控'), findsOneWidget);
  });
}
