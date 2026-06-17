import 'package:flutter_test/flutter_test.dart';
import 'package:app_tunnel/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AppTunnelApp());
    await tester.pumpAndSettle();

    expect(find.text('App Tunnel'), findsOneWidget);
    expect(find.text('App Tunnel - Remote Terminal'), findsOneWidget);
  });
}
