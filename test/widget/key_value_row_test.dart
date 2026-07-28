import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/shared/widgets/common.dart';

/// `KeyValueRow` renders nearly every figure in the app — the passbook, group
/// and member reports, and the agent's view of a group. It is a Row with two
/// Texts, so on a narrow handset a long label beside a large amount used to
/// overflow it.
///
/// The rule these pin: the label may shrink and ellipsize; the amount never
/// may. A truncated label is untidy, a truncated amount is a wrong number.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size logical, Widget child) async {
    tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: child,
      ))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lays out a long label and a large amount on a small phone',
      (tester) async {
    await pumpAt(
      tester,
      const Size(320, 480),
      const KeyValueRow('Loans given out this cycle', 'KSh 1,850,000.00'),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('KSh 1,850,000.00'), findsOneWidget);
  });

  testWidgets('shows the amount in full even when the label must give way',
      (tester) async {
    // The label is deliberately absurd; the figure must still be readable.
    await pumpAt(
      tester,
      const Size(320, 480),
      const KeyValueRow(
        'Total contributions received from every member during this savings cycle',
        'KSh 2,400,000.00',
      ),
    );
    expect(tester.takeException(), isNull);
    final amount = tester.widget<Text>(find.text('KSh 2,400,000.00'));
    // No ellipsis on the money.
    expect(amount.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('still lays out when emphasised', (tester) async {
    await pumpAt(
      tester,
      const Size(320, 480),
      const KeyValueRow('Still owing', 'KSh 1,200,000.00', emphasize: true),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('is unchanged on a roomy screen', (tester) async {
    await pumpAt(
      tester,
      const Size(430, 932),
      const KeyValueRow('Total savings', 'KSh 12,500.00'),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Total savings'), findsOneWidget);
    expect(find.text('KSh 12,500.00'), findsOneWidget);
  });

  testWidgets('handles an empty label without collapsing', (tester) async {
    await pumpAt(tester, const Size(320, 480), const KeyValueRow('', 'KSh 0.00'));
    expect(tester.takeException(), isNull);
    expect(find.text('KSh 0.00'), findsOneWidget);
  });
}
