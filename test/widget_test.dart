import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famli/app.dart';

void main() {
  testWidgets('App shell renders the splash screen first', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FamliApp()));
    await tester.pump();

    expect(find.text('Preparing Famli...'), findsOneWidget);
  });
}
