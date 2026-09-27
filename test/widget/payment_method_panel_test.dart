import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/services/remote_payment_providers_api.dart';
import 'package:intellicash_mobile/l10n/app_localizations.dart';
import 'package:intellicash_mobile/shared/widgets/payment_method_panel.dart';

/// The payment card every money action uses: Cash, M-Pesa (a prompt, no code),
/// M-Pesa Classic (the treasurer types the code) and Paystack. No Card.
void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
      );

  testWidgets('offers the four methods, never Card', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final code = TextEditingController();
    await tester.pumpWidget(host(PaymentMethodPanel(
      value: PaymentMethod.cash,
      online: true,
      codeController: code,
      onChanged: (_) {},
    )));
    expect(PaymentMethod.offered, [PaymentMethod.cash, PaymentMethod.mpesa, PaymentMethod.mpesaClassic, PaymentMethod.paystack]);
    expect(find.bySemanticsLabel(RegExp('^Cash')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^M-Pesa\\.')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^M-Pesa Classic')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Paystack')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Card')), findsNothing);
    // No code field unless M-Pesa Classic is chosen.
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('M-Pesa needs no code; M-Pesa Classic asks for it and checks it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    expect(PaymentMethod.mpesa.needsReference, isFalse);
    expect(PaymentMethod.mpesaClassic.needsReference, isTrue);
    expect(PaymentMethod.paystack.needsReference, isFalse);

    final formKey = GlobalKey<FormState>();
    final code = TextEditingController();
    await tester.pumpWidget(host(Form(
      key: formKey,
      child: PaymentMethodPanel(
        value: PaymentMethod.mpesaClassic,
        online: true,
        codeController: code,
        onChanged: (_) {},
      ),
    )));
    expect(find.byType(TextFormField), findsOneWidget);

    code.text = 'abc';
    expect(formKey.currentState!.validate(), isFalse);
    code.text = 'slk4h2x9y1';
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('offline, the online methods show but cannot be chosen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final chosen = <PaymentMethod>[];
    await tester.pumpWidget(host(PaymentMethodPanel(
      value: PaymentMethod.cash,
      online: false,
      codeController: TextEditingController(),
      onChanged: chosen.add,
    )));
    await tester.tap(find.bySemanticsLabel(RegExp('^Paystack')));
    await tester.tap(find.bySemanticsLabel(RegExp('^M-Pesa Classic')));
    await tester.pump();
    expect(chosen, [PaymentMethod.mpesaClassic]);
    expect(find.textContaining('Needs the group online'), findsNWidgets(2));
  });

  testWidgets('a provider the group switched off shows but cannot be chosen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final chosen = <PaymentMethod>[];
    await tester.pumpWidget(host(PaymentMethodPanel(
      value: PaymentMethod.cash,
      online: true,
      switchedOff: const {PaymentMethod.paystack},
      codeController: TextEditingController(),
      onChanged: chosen.add,
    )));
    await tester.tap(find.bySemanticsLabel(RegExp('^Paystack')));
    await tester.tap(find.bySemanticsLabel(RegExp('^M-Pesa\\.')));
    await tester.pump();
    expect(chosen, [PaymentMethod.mpesa]);
    expect(find.text('Switched off for this group'), findsOneWidget);
  });

  test('payment settings: no saved row means both on; saved empty means off', () {
    final defaults = GroupPaymentSettings.fromJson({
      'settings': {'collectionMode': null, 'enabledProviders': ['MPESA_DARAJA', 'PAYSTACK'], 'ownCredentialProviders': []},
    });
    expect(defaults.collectionMode, 'SYSTEM');
    expect(defaults.isOn(GroupPaymentSettings.mpesa), isTrue);

    final off = GroupPaymentSettings.fromJson({
      'settings': {'collectionMode': 'SYSTEM', 'enabledProviders': <String>[], 'memberSelfPayEnabled': true},
    });
    expect(off.enabledProviders, isEmpty);

    // Switching one keeps the rest of the row, in a stable order.
    final json = off.withProvider(GroupPaymentSettings.paystack, true).withProvider(GroupPaymentSettings.mpesa, true).toJson();
    expect(json, {
      'collectionMode': 'SYSTEM',
      'enabledProviders': ['MPESA_DARAJA', 'PAYSTACK'],
      'memberSelfPayEnabled': true,
    });
  });
}
