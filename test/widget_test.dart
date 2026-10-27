import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenantflow_client/main.dart';

void main() {
  testWidgets('demo data renders and filters without a server', (tester) async {
    await tester.pumpWidget(const TenantFlowApp());
    await tester.pumpAndSettle();
    expect(find.text('Review tenant isolation'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('No work items in this view.'), findsOneWidget);
    expect(find.text('Review tenant isolation'), findsNothing);
  });
}
