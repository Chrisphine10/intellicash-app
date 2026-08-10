import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';

/// A coaching topic, or an axis the group scores the coaching on.
class MentorshipEntry {
  const MentorshipEntry({required this.key, required this.title, this.description});

  final String key;
  final String title;
  final String? description;

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        if (description != null) 'description': description,
      };

  factory MentorshipEntry.fromJson(Map<String, dynamic> json) => MentorshipEntry(
        key: '${json['key']}',
        title: '${json['title']}',
        description: json['description'] as String?,
      );
}

class MentorshipCatalogue {
  const MentorshipCatalogue({required this.topics, required this.dimensions});

  final List<MentorshipEntry> topics;
  final List<MentorshipEntry> dimensions;
}

/// The list of topics and rating dimensions the phone renders.
///
/// Cached in preferences rather than the database on purpose: it is small,
/// read-only reference data with no relationships, and pushing it into sqflite
/// would mean another schema version for a list of strings.
///
/// It ships with a built-in copy of the seeded list so a brand-new install can
/// record coaching before it has ever had signal. The server's version wins
/// whenever one has been fetched — IWL edits these, and a phone that insisted
/// on its compiled-in copy would quietly ignore them.
class MentorshipCatalogueStore {
  MentorshipCatalogueStore({ApiClient? client}) : _client = client;

  final ApiClient? _client;

  static const _kTopics = 'mentorship_topics_json';
  static const _kDimensions = 'mentorship_dimensions_json';

  /// Matches `prisma/seed-mentorship-topics.ts`. Kept in step by hand, and
  /// harmless if it drifts: the moment the phone syncs, the server's list
  /// replaces it.
  static const _builtInTopics = <MentorshipEntry>[
    MentorshipEntry(key: 'record_keeping', title: 'Record keeping'),
    MentorshipEntry(key: 'loan_management', title: 'Loan management'),
    MentorshipEntry(key: 'governance', title: 'Governance and leadership'),
    MentorshipEntry(key: 'conflict_resolution', title: 'Conflict resolution'),
    MentorshipEntry(key: 'financial_literacy', title: 'Financial literacy'),
    MentorshipEntry(key: 'business_skills', title: 'Business skills'),
    MentorshipEntry(key: 'digital_tools', title: 'Using Intelli-Cash'),
    MentorshipEntry(key: 'social_fund', title: 'Social fund and welfare'),
  ];

  static const _builtInDimensions = <MentorshipEntry>[
    MentorshipEntry(key: 'clarity', title: 'Was the advice clear?'),
    MentorshipEntry(key: 'usefulness', title: 'Was it useful to the group?'),
    MentorshipEntry(key: 'respect', title: 'Were you treated with respect?'),
    MentorshipEntry(key: 'preparedness', title: 'Was the agent prepared?'),
  ];

  Future<MentorshipCatalogue> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MentorshipCatalogue(
      topics: _decode(prefs.getString(_kTopics)) ?? _builtInTopics,
      dimensions: _decode(prefs.getString(_kDimensions)) ?? _builtInDimensions,
    );
  }

  /// Refreshes from the server when there is signal.
  ///
  /// Returns false rather than throwing when there is none — an agent about to
  /// record coaching should get the cached list, not an error dialog.
  Future<bool> refresh() async {
    final client = _client;
    if (client == null) return false;

    try {
      final data = await client.getData('/mentorship-topics');
      final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
      final topics = _fromWire(map['topics']);
      final dimensions = _fromWire(map['dimensions']);
      // An empty list from the server is treated as "nothing to say", not as an
      // instruction to blank the phone: an agent with no topics at all cannot
      // record anything.
      if (topics.isEmpty && dimensions.isEmpty) return false;

      final prefs = await SharedPreferences.getInstance();
      if (topics.isNotEmpty) {
        await prefs.setString(
          _kTopics,
          jsonEncode(topics.map((entry) => entry.toJson()).toList()),
        );
      }
      if (dimensions.isNotEmpty) {
        await prefs.setString(
          _kDimensions,
          jsonEncode(dimensions.map((entry) => entry.toJson()).toList()),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  List<MentorshipEntry> _fromWire(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MentorshipEntry.fromJson)
        .toList();
  }

  List<MentorshipEntry>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return null;
      final entries =
          parsed.whereType<Map<String, dynamic>>().map(MentorshipEntry.fromJson).toList();
      return entries.isEmpty ? null : entries;
    } catch (_) {
      // Corrupt cache: fall back to the built-in list rather than showing an
      // agent an empty screen they cannot get past.
      return null;
    }
  }
}
