import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';

/// The group's collective enterprise, recorded during a visit.
///
/// Online-only, deliberately. Unlike the scorecard and the action plan — which
/// an agent fills in standing with the group and must work with no signal —
/// this is a short annual-ish profile that is edited rarely and read in the
/// office. Giving it its own offline table and sync path would be three more
/// moving parts for a form nobody fills in twice in a week.
///
/// It says so plainly when there is no connection rather than pretending to
/// save, which is the failure that would actually cost an agent their work.
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({
    super.key,
    required this.remoteGroupId,
    required this.groupName,
    required this.client,
    this.remoteVisitId,
  });

  final String remoteGroupId;
  final String groupName;
  final ApiClient client;

  /// Recording against a visit is what makes "between visits" a question with
  /// an answer. Null when the visit has not reached the server yet.
  final String? remoteVisitId;

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _enterprise = TextEditingController();
  final _revenue = TextEditingController();
  final _costs = TextEditingController();
  final _employs = TextEditingController();
  final _challenge = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [_enterprise, _revenue, _costs, _employs, _challenge]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.client
          .getData('/groups/${widget.remoteGroupId}/business-profile');
      final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
      final profile = map['profile'] as Map<String, dynamic>?;

      if (!mounted) return;
      setState(() {
        if (profile != null) {
          _enterprise.text = '${profile['enterpriseType'] ?? ''}';
          // Money is held in CENTS end to end; only this field converts, and
          // only for display.
          _revenue.text = _toShillings(profile['monthlyRevenueCents']);
          _costs.text = _toShillings(profile['monthlyCostsCents']);
          _employs.text = profile['employsPeople'] == null
              ? ''
              : '${profile['employsPeople']}';
          _challenge.text = '${profile['mainChallenge'] ?? ''}';
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the profile. You need a connection for this one.';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });

    try {
      await widget.client.putData(
        '/groups/${widget.remoteGroupId}/business-profile',
        body: {
          if (_enterprise.text.trim().isNotEmpty) 'enterpriseType': _enterprise.text.trim(),
          'monthlyRevenueCents': _toCents(_revenue.text),
          'monthlyCostsCents': _toCents(_costs.text),
          'employsPeople': int.tryParse(_employs.text.trim()),
          if (_challenge.text.trim().isNotEmpty) 'mainChallenge': _challenge.text.trim(),
          if (widget.remoteVisitId != null) 'visitId': widget.remoteVisitId,
        },
      );
      if (!mounted) return;
      setState(() => _message = 'Saved.');
    } catch (_) {
      if (!mounted) return;
      // Named plainly. Silently failing here would lose what the agent typed
      // while looking like it worked.
      setState(() => _error = 'Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _toShillings(dynamic cents) {
    if (cents is! num) return '';
    return (cents / 100).toStringAsFixed(0);
  }

  static int? _toCents(String value) {
    final shillings = double.tryParse(value.trim());
    if (shillings == null) return null;
    return (shillings * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessProfileGroupBusiness)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  l10n.businessProfileWhatDoesTheGroupRun,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  l10n.businessProfileTheGroupSOwnEnterpriseNot,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                if (_message != null)
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                TextField(
                  controller: _enterprise,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: l10n.businessProfileTypeOfBusiness,
                    hintText: l10n.businessProfileEGPoultryCerealBuying,
                  ),
                ),
                TextField(
                  controller: _revenue,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.businessProfileMoneyInEachMonthKes,
                  ),
                ),
                TextField(
                  controller: _costs,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.businessProfileCostsEachMonthKes,
                  ),
                ),
                TextField(
                  controller: _employs,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.businessProfilePeopleItEmploys,
                  ),
                ),
                TextField(
                  controller: _challenge,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: l10n.businessProfileBiggestProblemTheyFace,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.remoteVisitId == null
                      ? l10n.businessProfileThisVisitHasNotSyncedYet
                      : l10n.businessProfileSavedAgainstThisVisitSoNext,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving || _loading ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ),
      ),
    );
  }
}
