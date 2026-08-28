import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/location/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/mentorship_repository.dart';
import '../../data/services/mentorship_sync_service.dart';
import '../../data/repositories/visit_repository.dart';
import '../../data/services/visit_sync_service.dart';
import '../../shared/widgets/common.dart';
import '../../core/network/api_client.dart';
import 'business_profile_screen.dart';
import 'agreed_actions_card.dart';
import 'open_action_items_card.dart';
import 'visit_assessment_screen.dart';
import 'visit_mentorship_screen.dart';
import '../../l10n/app_localizations.dart';

/// Recording a field visit.
///
/// There is no PIN step. A visit used to open with a 4-digit PIN held by the
/// group — their attestation that the agent was in front of them — and that was
/// removed on the owner's instruction. What a visit now carries is the agent's
/// signed-in session, the GPS fix (adjudicated by the server against the
/// group's registered point, never by this phone), the device id and the time.
///
/// Every step writes to the local database as it happens. An agent whose
/// battery dies halfway through must be able to resume, and cannot be asked to
/// remember what they typed once they have walked away from the group.
///
/// Nothing here blocks on the network. The visit is finished on the phone and
/// the outbox gets it to the server later — which is the only design that works
/// where these groups actually meet.
class RecordVisitScreen extends StatefulWidget {
  const RecordVisitScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  State<RecordVisitScreen> createState() => _RecordVisitScreenState();
}

class _RecordVisitScreenState extends State<RecordVisitScreen> {
  final _notesController = TextEditingController();
  final _locationNoteController = TextEditingController();

  LocalVisit? _visit;
  final _assessments = AssessmentRepository();
  final _mentorship = MentorshipRepository();

  /// A one-line recap of the scorecard, so an agent about to hit Finish can
  /// see they left half of it blank.
  String? _assessmentSummary;

  /// A one-line recap of the coaching, so an agent about to hit Finish can see
  /// they never handed the phone over to be scored.
  String? _mentorshipSummary;
  bool _loading = true;
  bool _capturingLocation = false;
  bool _submitting = false;
  LocationFailure? _locationFailure;
  String _visitType = 'FOLLOW_UP';

  static const _visitTypes = <String, String>{
    'INITIAL': 'First visit',
    'FOLLOW_UP': 'Follow-up',
    'QUARTERLY_REVIEW': 'Quarterly review',
    'INTELLI_CASH_SUPPORT': 'Intelli-Cash support',
    'UNANNOUNCED': 'Unannounced check',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _locationNoteController.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    // Captured before any await: using `context` afterwards is unsound because
    // the screen may have been disposed while the database was busy.
    final repository = context.read<VisitRepository>();

    // Resume rather than start again. One occasion must not become two records.
    final existing = await repository.openDraftFor(widget.groupId);
    if (existing != null) {
      if (!mounted) return;
      setState(() {
        _visit = existing;
        _visitType = existing.visitType;
        _notesController.text = existing.notes ?? '';
        _locationNoteController.text = existing.locationNote ?? '';
        _loading = false;
      });
      return;
    }

    final visit = await repository.start(
      remoteGroupId: widget.groupId,
      groupName: widget.groupName,
    );
    if (!mounted) return;
    setState(() {
      _visit = visit;
      _loading = false;
    });
    await _captureLocation();
  }

  Future<void> _captureLocation() async {
    final visit = _visit;
    if (visit == null) return;
    setState(() {
      _capturingLocation = true;
      _locationFailure = null;
    });

    final repository = context.read<VisitRepository>();
    final result = await const LocationService().current();
    if (!mounted) return;

    if (result.hasFix) {
      final reading = result.reading!;
      await repository.recordLocation(
        id: visit.id,
        latitude: reading.latitude,
        longitude: reading.longitude,
        accuracyM: reading.accuracyM,
        capturedAt: reading.capturedAt,
      );
      final refreshed = await repository.byId(visit.id);
      if (!mounted) return;
      setState(() {
        _visit = refreshed;
        _capturingLocation = false;
      });
      return;
    }

    setState(() {
      _capturingLocation = false;
      _locationFailure = result.failure;
    });
  }

  Future<void> _submit() async {
    final visit = _visit;
    if (visit == null || _submitting) return;
    setState(() => _submitting = true);

    final repository = context.read<VisitRepository>();
    final sync = context.read<VisitSyncService>();

    await repository.saveDetails(
      id: visit.id,
      visitType: _visitType,
      notes: _notesController.text.trim(),
      locationNote: _locationNoteController.text.trim(),
    );
    await repository.markReadyToSend(visit.id);
    await sync.queue(visit.id);

    // Try immediately, but do not wait on it or report failure as failure: the
    // visit is safely recorded either way and the outbox will keep trying.
    unawaited(sync.pushDue());

    if (!mounted) return;
    showAppSnack(context, 'Visit saved. It will sync when you have signal.');
    Navigator.of(context).pop(true);
  }

  String get _locationSummary {
    final visit = _visit;
    if (visit != null && visit.hasLocation) {
      final accuracy = visit.accuracyM;
      final precision = accuracy == null ? '' : ' · accurate to ${accuracy.round()} m';
      return '${visit.latitude!.toStringAsFixed(5)}, '
          '${visit.longitude!.toStringAsFixed(5)}$precision';
    }
    return switch (_locationFailure) {
      LocationFailure.servicesDisabled => 'Location is switched off on this phone.',
      LocationFailure.denied => 'Location permission was declined.',
      LocationFailure.deniedForever =>
        'Location permission is blocked. You can turn it on in Settings.',
      LocationFailure.timedOut => 'No GPS fix yet — this can take a moment indoors.',
      LocationFailure.unavailable => 'Location is unavailable on this phone.',
      null => 'Not captured yet.',
    };
  }

  /// Opens the scorecard, then refreshes the one-line summary shown above.
  ///
  /// Nothing is submitted from that screen — answers are already on disk, and
  /// the visit's own Finish step is what queues the whole document.
  Future<void> _openAssessment() async {
    final visit = _visit;
    if (visit == null) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitAssessmentScreen(
          visitId: visit.id,
          groupName: widget.groupName,
        ),
      ),
    );

    final score = await _assessments.rescore(visit.id);
    if (!mounted) return;
    setState(() {
      _assessmentSummary = score == null
          ? null
          : '${score.earnedPoints.toStringAsFixed(0)} of '
              '${score.maxPoints.toStringAsFixed(0)} points'
              '${score.bandLabel == null ? '' : ' · ${score.bandLabel}'}'
              '${score.complete ? '' : ' · ${score.unansweredKeys.length} unanswered'}';
    });
  }

  /// Opens the coaching screen, then refreshes the one-line recap.
  Future<void> _openMentorship() async {
    final visit = _visit;
    if (visit == null) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitMentorshipScreen(
          visitId: visit.id,
          groupName: widget.groupName,
          mentorship: _mentorship,
        ),
      ),
    );

    final sessions = await _mentorship.sessionsFor(visit.id);
    final ratings = await _mentorship.ratingsFor(visit.id);
    if (!mounted) return;
    setState(() {
      _mentorshipSummary = sessions.isEmpty && ratings.isEmpty
          ? null
          : '${sessions.length} topic${sessions.length == 1 ? '' : 's'}'
              '${ratings.isEmpty ? ' · not yet scored' : ' · scored by the group'}';
    });
  }

  Future<void> _openBusinessProfile() async {
    final visit = _visit;
    if (visit == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessProfileScreen(
          remoteGroupId: widget.groupId,
          groupName: widget.groupName,
          client: context.read<ApiClient>(),
          // Null until the visit itself has synced — the profile still saves
          // against the group, just without an occasion to compare against.
          remoteVisitId: visit.remoteId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final visit = _visit;
    final hasFix = visit?.hasLocation ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionLabel('Visit type'),
          Card(
            child: Column(
              children: [
                // A plain list rather than RadioListTile: that widget's
                // groupValue/onChanged pair is deprecated in favour of a
                // RadioGroup ancestor, and this matches how the rest of the
                // app renders a single choice anyway.
                for (final entry in _visitTypes.entries)
                  ListTile(
                    dense: true,
                    onTap: () => setState(() => _visitType = entry.key),
                    leading: Icon(
                      _visitType == entry.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _visitType == entry.key
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                  ),
              ],
            ),
          ),
          const SectionLabel('Where you are'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasFix ? Icons.location_on_outlined : Icons.location_off_outlined,
                        size: 20,
                        color: hasFix ? AppColors.primary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_locationSummary,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Said plainly, because an agent who thinks a missing fix
                  // will lose their work will start faking one.
                  Text(
                    l10n.recordVisitAVisitCanStillBeRecorded,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _capturingLocation ? null : _captureLocation,
                          icon: _capturingLocation
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(hasFix ? 'Update location' : 'Capture location'),
                        ),
                      ),
                      if (_locationFailure == LocationFailure.deniedForever) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => const LocationService().openSettings(),
                            child: Text(l10n.recordVisitSettings),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!hasFix) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _locationNoteController,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.recordVisitWhyNotOptional,
                hintText: 'e.g. the group met at the chief\'s camp',
              ),
            ),
          ],
          const SectionLabel('Before you start'),
          if (_visit != null)
            OpenActionItemsCard(
              remoteGroupId: widget.groupId,
              visitId: _visit!.id,
              remoteVisitId: _visit!.remoteId,
              mentorship: _mentorship,
              sync: context.read<MentorshipSyncService>(),
            ),
          const SectionLabel('Assessment'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(l10n.recordVisitScoreTheGroup),
              subtitle: Text(
                _assessmentSummary ?? 'Work through the scorecard with the officials.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _visit == null ? null : _openAssessment,
            ),
          ),
          const SectionLabel('Mentorship'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text("Coaching and the group's rating"),
              subtitle: Text(
                _mentorshipSummary ?? l10n.recordVisitRecordWhatYouCoachedOnThen,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _visit == null ? null : _openMentorship,
            ),
          ),
          // After the coaching, not before it: what the group agrees to do is
          // the OUTPUT of the conversation, and an agent asked to fill this in
          // first has nothing to write down yet.
          const SectionLabel('Action plan'),
          if (_visit != null)
            AgreedActionsCard(
              remoteGroupId: widget.groupId,
              visitId: _visit!.id,
              mentorship: _mentorship,
            ),
          const SectionLabel('Group business'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(l10n.recordVisitTheGroupSEnterprise),
              subtitle: Text(
                l10n.recordVisitWhatTheyRunTogetherAnd,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _visit == null ? null : _openBusinessProfile,
            ),
          ),
          const SectionLabel('Notes'),
          TextField(
            controller: _notesController,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: l10n.recordVisitWhatYouFound,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.check, size: 18),
            label: Text(_submitting ? 'Saving…' : 'Finish visit'),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.recordVisitSavedOnThisPhoneFirst,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
