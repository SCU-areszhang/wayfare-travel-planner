import 'package:flutter_test/flutter_test.dart';
import 'package:wayfare_travel_planner/main.dart';

void main() {
  testWidgets('Wayfare app renders home dashboard', (tester) async {
    await tester.pumpWidget(const WayfareApp());
    await tester.pumpAndSettle();

    expect(find.text('Wayfare'), findsOneWidget);
    expect(find.text('Recommended for You'), findsOneWidget);
    expect(find.text('Create New Itinerary'), findsOneWidget);
  });
}
