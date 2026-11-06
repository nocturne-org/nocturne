import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/main.dart';
import 'package:nocturne/presentation/screens/bedtime_screen.dart';

void main() {
  testWidgets('NocturneApp startet mit leerem AMOLED-Container',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NocturneApp(),
      ),
    );

    expect(find.byType(BedtimeScreen), findsOneWidget);
    expect(find.text('Nocturne Bedtime Audio'), findsOneWidget);
  });
}
