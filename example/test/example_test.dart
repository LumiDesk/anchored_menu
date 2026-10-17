import 'package:anchored_menu_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example opens a nested menu and selects an action', (
    tester,
  ) async {
    await tester.pumpWidget(const AnchoredMenuExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Sort'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(find.text('Selected: List view'), findsOneWidget);
  });
}
