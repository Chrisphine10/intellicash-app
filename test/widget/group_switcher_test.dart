import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:intellicash_mobile/data/models/remote/membership.dart';
import 'package:intellicash_mobile/features/member/join_group_screen.dart';

Membership _membership(String name, {bool active = false}) => Membership(
      membershipId: 'link-$name',
      memberId: 'member-$name',
      groupId: 'group-$name',
      groupName: name,
      memberName: 'Faith Achieng',
      isActive: active,
    );

Future<void> _pump(WidgetTester tester, List<Membership> memberships,
    {ValueChanged<Membership>? onSwitch}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GroupSwitcher(
          memberships: memberships,
          onSwitch: onSwitch ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('GroupSwitcher', () {
    testWidgets('stays out of the way for someone in a single group',
        (tester) async {
      // Most members save with one group and should never be asked to think
      // about which one they are looking at.
      await _pump(tester, [_membership('Tujijenge', active: true)]);
      expect(find.text('Viewing'), findsNothing);
      expect(find.text('Tujijenge'), findsNothing);
    });

    testWidgets('is hidden entirely when there are no groups', (tester) async {
      await _pump(tester, const []);
      expect(find.byType(PopupMenuButton<Membership>), findsNothing);
    });

    testWidgets('names the group in view when there are several',
        (tester) async {
      await _pump(tester, [
        _membership('Tujijenge'),
        _membership('Umoja', active: true),
      ]);
      expect(find.text('Viewing'), findsOneWidget);
      expect(find.text('Umoja'), findsOneWidget);
    });

    testWidgets('falls back to the first group when none is marked active',
        (tester) async {
      // Defensive: a stale list must still render something sensible rather
      // than throwing on firstWhere.
      await _pump(tester, [_membership('Tujijenge'), _membership('Umoja')]);
      expect(find.text('Tujijenge'), findsOneWidget);
    });

    testWidgets('hands back the group the member picked', (tester) async {
      Membership? picked;
      await _pump(
        tester,
        [_membership('Tujijenge', active: true), _membership('Umoja')],
        onSwitch: (m) => picked = m,
      );

      await tester.tap(find.byType(PopupMenuButton<Membership>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Umoja').last);
      await tester.pumpAndSettle();

      expect(picked?.groupName, 'Umoja');
    });
  });

  group('Membership.fromJson', () {
    test('reads what the server sends', () {
      final m = Membership.fromJson(const {
        'membershipId': 'link-1',
        'memberId': 'member-1',
        'groupId': 'group-1',
        'groupName': 'Tujijenge Women VSLA',
        'groupCode': 'IWL-KBU-0001',
        'memberName': 'Faith Achieng',
        'isActive': true,
      });
      expect(m.groupName, 'Tujijenge Women VSLA');
      expect(m.groupCode, 'IWL-KBU-0001');
      expect(m.isActive, isTrue);
    });

    test('treats a missing isActive as not active', () {
      // A group that isn't explicitly in view must never be shown as such.
      final m = Membership.fromJson(const {
        'membershipId': 'link-1',
        'memberId': 'member-1',
        'groupId': 'group-1',
        'groupName': 'Umoja',
        'memberName': 'Faith Achieng',
      });
      expect(m.isActive, isFalse);
      expect(m.groupCode, isNull);
    });
  });

  group('JoinRequest.fromJson', () {
    test('defaults to pending and reads the review note', () {
      final r = JoinRequest.fromJson(const {
        'id': 'req-1',
        'requestedName': 'Faith Achieng',
        'phone': '254700000202',
        'reviewNotes': 'Come to a meeting first.',
      });
      expect(r.isPending, isTrue);
      expect(r.reviewNotes, 'Come to a meeting first.');
    });

    test('an answered request is no longer pending', () {
      final r = JoinRequest.fromJson(const {
        'id': 'req-1',
        'requestedName': 'Faith Achieng',
        'phone': '254700000202',
        'status': 'APPROVED',
      });
      expect(r.isPending, isFalse);
    });
  });
}
