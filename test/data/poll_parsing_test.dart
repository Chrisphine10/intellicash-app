import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/remote/poll_models.dart';

/// Voting had no mobile test at all.
///
/// The fixture below is a VERBATIM capture of `GET /polls/:id` from a running
/// server on 1 Aug 2026 — a closed election, with a candidate labelled from a
/// member and a nested `member` object. Hand-written fixtures agree with
/// whatever the parser happens to do; a captured one does not.
///
/// The failure this guards is silent: a mistyped JSON key parses to zero or
/// null, the ballot renders, and the group is shown a tally that is simply
/// wrong. Nothing throws.
void main() {
  Map<String, dynamic> closedElection() => {
        "id": "cmsaufrnk001tv0qkl69p70v9",
        "groupId": "cmsauernn001bv0ls8uaqhfde",
        "meetingId": null,
        "type": "ROLE_ELECTION",
        "title": "Who should be treasurer?",
        "description": null,
        "targetRole": "TREASURER",
        "status": "CLOSED",
        "secretBallot": false,
        "createdByUserId": "cmsaueuz0001yv0lsm1aep0ap",
        "closesAt": null,
        "closedAt": "2026-08-01T20:48:22.585Z",
        "resultSummary": "Mary Njeri elected Treasurer with 1 of 1 votes",
        "createdAt": "2026-08-01T20:48:21.440Z",
        "updatedAt": "2026-08-01T20:48:22.587Z",
        "meeting": null,
        "options": [
          {
            "id": "cmsaufrnk001vv0qkpe6w91s1",
            "label": "Mary Njeri",
            "memberId": "cmsaueuu5001hv0lsjfa6lnwg",
            "position": 0,
            "member": {
              "id": "cmsaueuu5001hv0lsjfa6lnwg",
              "fullName": "Mary Njeri",
              "role": "CHAIRPERSON"
            },
            "voteCount": 1
          },
          {
            "id": "cmsaufrnk001wv0qkwn6pizm2",
            "label": "Agnes Muthoni",
            "memberId": "cmsaueuuc001nv0lsfjfuzpjb",
            "position": 1,
            "member": {
              "id": "cmsaueuuc001nv0lsfjfuzpjb",
              "fullName": "Agnes Muthoni",
              "role": "TREASURER"
            },
            "voteCount": 0
          }
        ],
        "totalVotes": 1,
        "myVote": null,
        "hasVoted": false
      };

  group('a closed election off the wire', () {
    test('reads the tally, not zeros', () {
      final poll = RemotePoll.fromJson(closedElection());
      expect(poll.totalVotes, 1);
      expect(poll.options.map((o) => o.voteCount).toList(), [1, 0]);
    });

    test('keeps the result sentence for the minute book', () {
      // The one field that must survive verbatim — it IS the resolution.
      final poll = RemotePoll.fromJson(closedElection());
      expect(poll.resultSummary, 'Mary Njeri elected Treasurer with 1 of 1 votes');
      expect(poll.isClosed, isTrue);
    });

    test('names the winner and does not invent one', () {
      final poll = RemotePoll.fromJson(closedElection());
      expect(poll.isTie, isFalse);
      expect(poll.winner?.label, 'Mary Njeri');
      expect(poll.isWinning(poll.options.first), isTrue);
      expect(poll.isWinning(poll.options.last), isFalse);
    });

    test('shows a candidate as a person, not an id', () {
      final poll = RemotePoll.fromJson(closedElection());
      expect(poll.options.first.memberName, 'Mary Njeri');
      // The office they hold today, humanised for the ballot row.
      expect(poll.options.first.memberRoleLabel, 'Chairperson');
      expect(poll.targetRoleLabel, 'Treasurer');
    });

    test('shares sum to the whole vote', () {
      final poll = RemotePoll.fromJson(closedElection());
      expect(poll.share(poll.options.first), 1.0);
      expect(poll.share(poll.options.last), 0.0);
    });
  });

  group('the cases that decide what a group is told', () {
    test('a TIE is reported as a tie, never resolved by the app', () {
      // Picking a winner from a tie would hand an office to whoever the
      // server happened to list first.
      final json = closedElection();
      (json['options'] as List)[1]['voteCount'] = 1;
      json['totalVotes'] = 2;

      final poll = RemotePoll.fromJson(json);
      expect(poll.isTie, isTrue);
      expect(poll.winner, isNull);
    });

    test('nobody has voted yet — no winner, no division by zero', () {
      final json = closedElection();
      for (final option in json['options'] as List) {
        option['voteCount'] = 0;
      }
      json['totalVotes'] = 0;

      final poll = RemotePoll.fromJson(json);
      expect(poll.isTie, isFalse);
      expect(poll.winner, isNull);
      expect(poll.share(poll.options.first), 0.0);
    });

    test('a secret ballot hides the choice but admits the vote', () {
      // hasVoted must stay true or the app cannot tell a member they have
      // already voted, and they will try again and be refused.
      final json = closedElection();
      json['secretBallot'] = true;
      json['myVote'] = null;
      json['hasVoted'] = true;

      final poll = RemotePoll.fromJson(json);
      expect(poll.secretBallot, isTrue);
      expect(poll.myVote, isNull);
      expect(poll.hasVoted, isTrue);
      // The tally is still public — secrecy is about who, not how many.
      expect(poll.totalVotes, 1);
    });

    test('an open vote the caller has already cast', () {
      final json = closedElection();
      json['status'] = 'OPEN';
      json['myVote'] = 'cmsaufrnk001vv0qkpe6w91s1';
      json['hasVoted'] = true;

      final poll = RemotePoll.fromJson(json);
      expect(poll.isOpen, isTrue);
      expect(poll.hasVoted, isTrue);
      expect(poll.myVote, 'cmsaufrnk001vv0qkpe6w91s1');
    });

    test('a decision is labelled a decision, not an election', () {
      final json = closedElection();
      json['type'] = 'DECISION';
      json['targetRole'] = null;
      final poll = RemotePoll.fromJson(json);
      expect(poll.isElection, isFalse);
      expect(poll.typeLabel, 'Decision');
      expect(poll.targetRoleLabel, isNull);
    });

    test('a sparse payload degrades instead of throwing', () {
      // An older server, or a trimmed list response, must not leave an
      // official staring at a crash mid-meeting.
      final poll = RemotePoll.fromJson({'id': 'p1'});
      expect(poll.options, isEmpty);
      expect(poll.totalVotes, 0);
      expect(poll.status, 'OPEN');
      expect(poll.hasVoted, isFalse);
      expect(poll.winner, isNull);
    });
  });
}
