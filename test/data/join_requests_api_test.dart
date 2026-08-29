import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';

/// What the group account's phone actually asks the server for.
///
/// `joinRequests` has taken an `all` flag since it was written and no screen
/// ever passed it, so the server only ever returned PENDING and the "already
/// approved / already declined" rows on the join-requests screen could not be
/// reached. These pin both halves: the flag reaches the URL, and the decision
/// carries the handover confirmation the server requires.
void main() {
  late List<String> requestedUrls;
  late List<Map<String, dynamic>> postedBodies;

  RemoteApi apiReturning(Object payload) {
    requestedUrls = [];
    postedBodies = [];

    final client = MockClient((http.Request request) async {
      requestedUrls.add(request.url.toString());
      if (request.method == 'POST' && request.body.isNotEmpty) {
        postedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return http.Response(
        jsonEncode({'data': payload}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    return RemoteApi(ApiClient(
      credentials: () => const ApiCredentials(
        baseUrl: 'https://example.test/api/v1',
        apiKey: 'ic_sk_test',
      ),
      httpClient: client,
    ));
  }

  Map<String, dynamic> request({
    String status = 'PENDING',
    String? willLinkToMemberId,
  }) =>
      {
        'id': 'req-1',
        'requestedName': 'Mary Wanjiku',
        'phone': '254757255710',
        'status': status,
        'createdAt': '2026-08-29T09:00:00.000Z',
        'willLinkToMemberId': willLinkToMemberId,
        'willLinkToMemberName': willLinkToMemberId == null ? null : 'Mary W.',
      };

  test('asks only for waiting requests by default', () async {
    final api = apiReturning([request()]);

    final requests = await api.joinRequests('group-1');

    expect(requestedUrls.single, endsWith('/groups/group-1/join-requests'));
    expect(requestedUrls.single, isNot(contains('status=')));
    expect(requests.single.isPending, isTrue);
  });

  test('asks for everything when the answered view is open', () async {
    final api = apiReturning([request(status: 'APPROVED')]);

    final requests = await api.joinRequests('group-1', all: true);

    expect(requestedUrls.single, contains('status=ALL'));
    expect(requests.single.isPending, isFalse);
    expect(requests.single.status, 'APPROVED');
  });

  test('reads the handover warning the server attaches to a match', () async {
    final api = apiReturning([request(willLinkToMemberId: 'member-9')]);

    final match = (await api.joinRequests('group-1')).single;

    // A phone number is typed at sign-up and nothing verifies it, so a match is
    // a claim. The screen must be able to tell the official whose passbook
    // accepting would hand over.
    expect(match.takesOverExistingRecords, isTrue);
    expect(match.willLinkToMemberId, 'member-9');
    expect(match.willLinkToMemberName, 'Mary W.');
  });

  test('sends the confirmed member id when approving a handover', () async {
    final api = apiReturning({'id': 'req-1', 'status': 'APPROVED'});

    await api.decideJoinRequest(
      'group-1',
      'req-1',
      approve: true,
      confirmMemberId: 'member-9',
    );

    expect(postedBodies.single['decision'], 'APPROVE');
    expect(postedBodies.single['confirmMemberId'], 'member-9');
  });

  test('sends no member id when approving someone new', () async {
    final api = apiReturning({'id': 'req-1', 'status': 'APPROVED'});

    await api.decideJoinRequest('group-1', 'req-1', approve: true);

    expect(postedBodies.single['decision'], 'APPROVE');
    expect(postedBodies.single.containsKey('confirmMemberId'), isFalse);
  });

  test('never sends a member id when declining', () async {
    final api = apiReturning({'id': 'req-1', 'status': 'REJECTED'});

    await api.decideJoinRequest(
      'group-1',
      'req-1',
      approve: false,
      notes: '  Not known to the group.  ',
      // Even if a caller passes one, declining must not carry a handover.
      confirmMemberId: 'member-9',
    );

    expect(postedBodies.single['decision'], 'REJECT');
    expect(postedBodies.single.containsKey('confirmMemberId'), isFalse);
    expect(postedBodies.single['notes'], 'Not known to the group.');
  });

  test('omits an empty reason rather than sending a blank one', () async {
    final api = apiReturning({'id': 'req-1', 'status': 'REJECTED'});

    await api.decideJoinRequest('group-1', 'req-1', approve: false, notes: '   ');

    expect(postedBodies.single.containsKey('notes'), isFalse);
  });
}
