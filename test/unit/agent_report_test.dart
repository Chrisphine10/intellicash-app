import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/remote/agent_report.dart';

void main() {
  group('AgentReportGroup.fromJson', () {
    test('reads a rated group', () {
      final g = AgentReportGroup.fromJson(const {
        'id': 'cmr-1',
        'name': 'Tujijenge Women VSLA',
        'code': 'IWL-KBU-0001',
        'memberCount': 18,
        'creditRating': {'band': 'B', 'score': 73, 'rated': true},
        'needsSupport': false,
      });
      expect(g.band, 'B');
      expect(g.score, 73);
      expect(g.rated, isTrue);
      expect(g.needsSupport, isFalse);
      expect(g.memberCount, 18);
    });

    test('a group nobody has rated counts as needing support', () {
      // The server decides this, and it treats "never assessed" as needing a
      // visit — an unrated group is precisely one an agent should look at.
      final g = AgentReportGroup.fromJson(const {
        'id': 'cmr-2',
        'name': 'Umoja Savings Group',
        'creditRating': null,
        'needsSupport': true,
      });
      expect(g.band, isNull);
      expect(g.rated, isFalse);
      expect(g.needsSupport, isTrue);
    });

    test('a band with rated false is not presented as a rating', () {
      final g = AgentReportGroup.fromJson(const {
        'id': 'cmr-3',
        'name': 'Pending Group',
        'creditRating': {'band': 'C', 'score': 0, 'rated': false},
        'needsSupport': true,
      });
      expect(g.rated, isFalse);
      expect(g.needsSupport, isTrue);
    });

    test('survives a group row with almost nothing in it', () {
      final g = AgentReportGroup.fromJson(const {'id': 'cmr-4'});
      expect(g.name, 'Group');
      expect(g.memberCount, 0);
      expect(g.score, 0);
      expect(g.needsSupport, isFalse);
    });
  });

  group('AgentReport.fromJson', () {
    test('reads the caseload summary the header shows', () {
      final r = AgentReport.fromJson(const {
        'generatedAt': '2026-07-19T10:00:00.000Z',
        'agent': {'name': 'Jane Wanjiru'},
        'summary': {
          'groups': 4,
          'rated': 3,
          'needSupport': 2,
          'totalMembers': 61,
        },
        'groups': [
          {'id': 'cmr-1', 'name': 'A', 'needsSupport': false},
          {'id': 'cmr-2', 'name': 'B', 'needsSupport': true},
        ],
      });
      expect(r.agentName, 'Jane Wanjiru');
      expect(r.groupCount, 4);
      expect(r.ratedCount, 3);
      expect(r.needSupportCount, 2);
      expect(r.totalMembers, 61);
      expect(r.groups, hasLength(2));
      expect(r.generatedAt, isNotNull);
    });

    test('an empty payload yields an empty caseload, not an error', () {
      final r = AgentReport.fromJson(const {});
      expect(r.groups, isEmpty);
      expect(r.groupCount, 0);
      expect(r.agentName, isNull);
      expect(r.generatedAt, isNull);
    });
  });
}
