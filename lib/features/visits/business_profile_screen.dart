import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../l10n/app_localizations.dart';

/// The businesses a group runs, recorded during a visit.
///
/// A group may run several — a poultry unit and a cereal store have different
/// margins, different buyers and different needs. This screen used to hold one
/// profile per group, so capturing the second meant overwriting the first.
///
/// Online-only, deliberately, and unchanged in that respect. Unlike the
/// scorecard and the action plan — which an agent fills in standing with the
/// group and must work with no signal — this is a short profile edited rarely
/// and read in the office. Giving it its own offline table and sync path would
/// be three more moving parts for a form nobody fills in twice in a week. It
/// says so plainly when there is no connection rather than pretending to save,
/// which is the failure that would actually cost an agent their work.
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

/// One enterprise as the server holds it.
class _Enterprise {
  _Enterprise(Map<String, dynamic> json)
      : id = '${json['id']}',
        name = '${json['name'] ?? ''}',
        enterpriseType = json['enterpriseType'] as String?,
        revenueCents = json['monthlyRevenueCents'] as int?,
        costsCents = json['monthlyCostsCents'] as int?,
        employs = json['employsPeople'] as int?,
        marketReach = json['marketReach'] as String?,
        marketReachLabel = json['marketReachLabel'] as String?,
        buyerCount = json['buyerCount'] as int?,
        hasFormalBuyerAgreement = json['hasFormalBuyerAgreement'] as bool?,
        mainChallenge = json['mainChallenge'] as String?,
        channels = ((json['marketChannels'] as List<dynamic>?) ?? const [])
            .map((entry) => '${(entry as Map<String, dynamic>)['key']}')
            .toList(),
        salesMonths = ((json['salesMonths'] as List<dynamic>?) ?? const [])
            .whereType<num>()
            .map((entry) => entry.toInt())
            .toList(),
        supportNeeds = ((json['supportNeeds'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        // Returned by the server on every read and previously discarded, so the
        // phone could not answer the one question the snapshots exist for.
        history = ((json['history'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

  final String id;
  final String name;
  final String? enterpriseType;
  final int? revenueCents;
  final int? costsCents;
  final int? employs;
  final String? marketReach;
  final String? marketReachLabel;
  final int? buyerCount;
  final bool? hasFormalBuyerAgreement;
  final String? mainChallenge;
  final List<String> channels;
  final List<int> salesMonths;
  final List<Map<String, dynamic>> supportNeeds;
  final List<Map<String, dynamic>> history;

  /// Revenue at the earliest dated reading against the latest.
  ///
  /// Null with fewer than two readings: there is no baseline, which is a
  /// different fact from no growth and must not be shown as zero.
  int? get revenueSinceFirstVisit {
    final readings = history
        .where((row) => row['monthlyRevenueCents'] is int)
        .toList()
      ..sort((a, b) => '${a['recordedAt']}'.compareTo('${b['recordedAt']}'));
    if (readings.length < 2) return null;
    return (readings.last['monthlyRevenueCents'] as int) -
        (readings.first['monthlyRevenueCents'] as int);
  }
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  List<_Enterprise> _enterprises = const [];

  /// The vocabularies, served rather than hardcoded so the ladder cannot drift
  /// apart between the phone, the console and the reports that read them.
  List<Map<String, dynamic>> _reachLadder = const [];
  List<Map<String, dynamic>> _channels = const [];
  List<Map<String, dynamic>> _needTypes = const [];

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the two calls INDEPENDENTLY.
  ///
  /// They used to be one `Future.wait`, so a failure on either blanked the
  /// screen — and the vocabularies are only needed to open the editor, not to
  /// read what is already recorded. An agent whose reference call failed saw no
  /// businesses at all, and the businesses had loaded perfectly.
  Future<void> _load() async {
    final l10n = L10n.of(context);
    String? failure;

    try {
      final list = await widget.client
          .getData('/groups/${widget.remoteGroupId}/enterprises');
      final map = list is Map<String, dynamic> ? list : const <String, dynamic>{};
      final parsed = ((map['enterprises'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_Enterprise.new)
          .toList();
      if (mounted) setState(() => _enterprises = parsed);
    } catch (error) {
      // Named for what actually happened. "Check your connection" for a group
      // outside this agent's caseload sends them to look at the wrong thing.
      failure = error is ApiException && error.statusCode == 404
          ? l10n.enterpriseGroupNotYours
          : l10n.enterpriseCouldNotLoad;
    }

    try {
      final reference = await widget.client.getData('/enterprise-reference');
      final map =
          reference is Map<String, dynamic> ? reference : const <String, dynamic>{};
      if (mounted) {
        setState(() {
          _reachLadder = ((map['marketReach'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _channels = ((map['marketChannels'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _needTypes = ((map['supportNeedTypes'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
        });
      }
    } catch (_) {
      // Not fatal: what is already recorded still reads. Only the editor's
      // pickers are affected, and it says so when opened.
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = failure;
    });
  }

  Future<void> _openEditor([_Enterprise? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EnterpriseEditor(
          client: widget.client,
          remoteGroupId: widget.remoteGroupId,
          remoteVisitId: widget.remoteVisitId,
          existing: existing,
          reachLadder: _reachLadder,
          channels: _channels,
        ),
      ),
    );

    if (saved == true && mounted) {
      final l10n = L10n.of(context);
      setState(() => _message = l10n.enterpriseSaved);
      await _load();
    }
  }

  Future<void> _addNeed(_Enterprise enterprise) async {
    final chosen = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SupportNeedSheet(needTypes: _needTypes),
    );
    if (chosen == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.client.postData(
        '/enterprises/${enterprise.id}/support-needs',
        body: {
          'needKey': chosen['needKey'],
          'priority': chosen['priority'],
          if (widget.remoteVisitId != null) 'raisedAtVisitId': widget.remoteVisitId,
        },
      );
      await _load();
    } catch (_) {
      if (mounted) {
        final l10n = L10n.of(context);
        setState(() => _error = l10n.enterpriseCouldNotSaveNeed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

                if (_error != null) _Banner(text: _error!, isError: true),
                if (_message != null) _Banner(text: _message!, isError: false),

                if (_enterprises.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        // Not the same as having none, and the wording says so:
                        // an empty record here is a question nobody has asked.
                        l10n.enterpriseNothingRecordedYet,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),

                for (final enterprise in _enterprises)
                  _EnterpriseCard(
                    enterprise: enterprise,
                    onEdit: () => _openEditor(enterprise),
                    onAddNeed: _saving ? null : () => _addNeed(enterprise),
                  ),

                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.enterpriseAddAnotherBusiness),
                ),

                const SizedBox(height: 12),
                Text(
                  widget.remoteVisitId == null
                      ? l10n.businessProfileThisVisitHasNotSyncedYet
                      : l10n.businessProfileSavedAgainstThisVisitSoNext,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: isError ? theme.colorScheme.errorContainer : theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isError
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _EnterpriseCard extends StatelessWidget {
  const _EnterpriseCard({
    required this.enterprise,
    required this.onEdit,
    required this.onAddNeed,
  });

  final _Enterprise enterprise;
  final VoidCallback onEdit;
  final VoidCallback? onAddNeed;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final margin = enterprise.revenueCents == null || enterprise.costsCents == null
        ? null
        : enterprise.revenueCents! - enterprise.costsCents!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(enterprise.name, style: theme.textTheme.titleMedium),
                ),
                TextButton(onPressed: onEdit, child: Text(l10n.enterpriseEdit)),
              ],
            ),
            if (enterprise.enterpriseType != null)
              Text(enterprise.enterpriseType!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),

            _Line(
              label: l10n.enterpriseMoneyInEachMonth,
              value: _money(l10n, enterprise.revenueCents),
            ),
            _Line(
              label: l10n.enterpriseCostsEachMonth,
              value: _money(l10n, enterprise.costsCents),
            ),
            _Line(label: l10n.enterpriseWhatIsLeft, value: _money(l10n, margin)),
            _Line(
              label: l10n.enterpriseHowFarItSells,
              // "Not asked" rather than a dash: the question has not been put
              // to them, which is different from them having no answer.
              value: enterprise.marketReachLabel ?? l10n.enterpriseNotAsked,
            ),
            _Line(
              label: l10n.enterpriseBuyersLastMonth,
              value: enterprise.buyerCount?.toString() ?? l10n.enterpriseNotAsked,
            ),
            _Line(
              label: l10n.enterpriseWrittenAgreementWithBuyer,
              value: enterprise.hasFormalBuyerAgreement == null
                  ? l10n.enterpriseNotAsked
                  : (enterprise.hasFormalBuyerAgreement!
                      ? l10n.enterpriseYes
                      : l10n.enterpriseNoInformal),
            ),
            // Everything below was being captured in the editor and never shown
            // back, so an agent filled it in, reopened the screen and could not
            // see it. The data was saved and returned the whole time.
            _Line(
              label: l10n.businessProfilePeopleItEmploys,
              value: enterprise.employs?.toString() ?? l10n.enterpriseNotAsked,
            ),
            if (enterprise.channels.isNotEmpty)
              _Line(
                label: l10n.enterpriseHowTheySell,
                value: enterprise.channels
                    .map((key) => _channelLabel(key))
                    .join(', '),
              ),
            // Only when it is actually seasonal: "sells in all twelve months"
            // is noise on a small screen.
            if (enterprise.salesMonths.isNotEmpty && enterprise.salesMonths.length < 12)
              _Line(
                label: l10n.enterpriseMonthsTheySellIn,
                value: (enterprise.salesMonths.toList()..sort())
                    .map((month) => _monthLabels[month - 1])
                    .join(', '),
              ),
            _Line(
              label: l10n.enterpriseReadingsTaken,
              value: enterprise.history.length.toString(),
            ),
            _Line(
              label: l10n.enterpriseRevenueSinceFirst,
              value: enterprise.revenueSinceFirstVisit == null
                  ? l10n.enterpriseNoBaselineYet
                  : _money(l10n, enterprise.revenueSinceFirstVisit),
            ),
            if (enterprise.mainChallenge != null &&
                enterprise.mainChallenge!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${l10n.businessProfileBiggestProblemTheyFace}: ${enterprise.mainChallenge}',
                  style: theme.textTheme.bodySmall,
                ),
              ),

            if (enterprise.supportNeeds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(l10n.enterpriseWhatTheyNeed, style: theme.textTheme.titleSmall),
              for (final need in enterprise.supportNeeds)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        need['status'] == 'MET' ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${need['needTitleSnapshot']}')),
                      if (need['priority'] == 'HIGH')
                        Text(l10n.enterpriseUrgent, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onAddNeed,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.enterpriseAddSomethingTheyNeed),
            ),
          ],
        ),
      ),
    );
  }

  /// Channel keys are rendered from the same list the editor uses. The server
  /// sends a label with each one, but the card only holds the keys, so this
  /// falls back to a readable form rather than printing EXPORT_AGENT at
  /// somebody.
  static String _channelLabel(String key) =>
      key.toLowerCase().replaceAll('_', ' ');

  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _money(L10n l10n, int? cents) {
    if (cents == null) return l10n.enterpriseNotRecorded;
    return 'KSh ${(cents / 100).round()}';
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Adds or edits one enterprise.
class _EnterpriseEditor extends StatefulWidget {
  const _EnterpriseEditor({
    required this.client,
    required this.remoteGroupId,
    required this.remoteVisitId,
    required this.existing,
    required this.reachLadder,
    required this.channels,
  });

  final ApiClient client;
  final String remoteGroupId;
  final String? remoteVisitId;
  final _Enterprise? existing;
  final List<Map<String, dynamic>> reachLadder;
  final List<Map<String, dynamic>> channels;

  @override
  State<_EnterpriseEditor> createState() => _EnterpriseEditorState();
}

class _EnterpriseEditorState extends State<_EnterpriseEditor> {
  final _name = TextEditingController();
  final _type = TextEditingController();
  final _revenue = TextEditingController();
  final _costs = TextEditingController();
  final _employs = TextEditingController();
  final _buyers = TextEditingController();
  final _challenge = TextEditingController();

  String? _reach;
  bool? _agreement;
  Set<String> _selectedChannels = <String>{};
  Set<int> _months = <int>{};

  bool _saving = false;
  String? _error;

  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _type.text = existing.enterpriseType ?? '';
      _revenue.text = _toShillings(existing.revenueCents);
      _costs.text = _toShillings(existing.costsCents);
      _employs.text = existing.employs?.toString() ?? '';
      _buyers.text = existing.buyerCount?.toString() ?? '';
      _challenge.text = existing.mainChallenge ?? '';
      _reach = existing.marketReach;
      _agreement = existing.hasFormalBuyerAgreement;
      _selectedChannels = existing.channels.toSet();
      _months = existing.salesMonths.toSet();
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _type, _revenue, _costs, _employs, _buyers, _challenge]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      final l10n = L10n.of(context);
      setState(() => _error = l10n.enterpriseNameRequired);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      if (_type.text.trim().isNotEmpty) 'enterpriseType': _type.text.trim(),
      'monthlyRevenueCents': _toCents(_revenue.text),
      'monthlyCostsCents': _toCents(_costs.text),
      'employsPeople': int.tryParse(_employs.text.trim()),
      'marketReach': _reach,
      'buyerCount': int.tryParse(_buyers.text.trim()),
      'marketChannels': _selectedChannels.toList(),
      // Left null until somebody asks. Sending false for an enterprise nobody
      // asked would report a gap that has not been measured.
      'hasFormalBuyerAgreement': _agreement,
      'salesMonths': _months.toList()..sort(),
      if (_challenge.text.trim().isNotEmpty) 'mainChallenge': _challenge.text.trim(),
      if (widget.remoteVisitId != null) 'visitId': widget.remoteVisitId,
    };

    try {
      if (widget.existing == null) {
        await widget.client
            .postData('/groups/${widget.remoteGroupId}/enterprises', body: body);
      } else {
        await widget.client.patchData('/enterprises/${widget.existing!.id}', body: body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      // Named plainly. Failing silently here would lose what the agent typed
      // while looking like it worked.
      final l10n = L10n.of(context);
      setState(() => _error = l10n.enterpriseCouldNotSave);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _toShillings(int? cents) {
    if (cents == null) return '';
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
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? l10n.enterpriseNewBusiness
              : l10n.enterpriseEditBusiness,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_error != null) _Banner(text: _error!, isError: true),

          TextField(
            controller: _name,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: l10n.enterpriseWhatIsItCalled,
              hintText: l10n.enterpriseNameHint,
            ),
          ),
          TextField(
            controller: _type,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: l10n.businessProfileTypeOfBusiness,
              hintText: l10n.businessProfileEGPoultryCerealBuying,
            ),
          ),
          TextField(
            controller: _revenue,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.businessProfileMoneyInEachMonthKes),
          ),
          TextField(
            controller: _costs,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.businessProfileCostsEachMonthKes),
          ),
          TextField(
            controller: _employs,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.businessProfilePeopleItEmploys),
          ),

          const SizedBox(height: 20),
          Text(l10n.enterpriseWhereTheySell, style: theme.textTheme.titleMedium),
          Text(
            // Said in the field officer's terms rather than as an indicator
            // name: what they are asking the group is how far the produce goes.
            l10n.enterpriseWhereTheySellHint,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            initialValue: _reach,
            decoration: InputDecoration(labelText: l10n.enterpriseHowFarItReaches),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(l10n.enterpriseNotAsked),
              ),
              for (final rung in widget.reachLadder)
                DropdownMenuItem<String>(
                  value: '${rung['key']}',
                  child: Text('${rung['label']}'),
                ),
            ],
            onChanged: (value) => setState(() => _reach = value),
          ),
          TextField(
            controller: _buyers,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.enterpriseHowManyBuyersLastMonth,
            ),
          ),

          const SizedBox(height: 12),
          Text(l10n.enterpriseHowTheySell, style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              // Several at once, because a group commonly uses more than one —
              // the farm gate for surplus, a trader for volume. A single choice
              // would force whoever captures it to pick a lie.
              for (final channel in widget.channels)
                FilterChip(
                  label: Text('${channel['label']}'),
                  selected: _selectedChannels.contains('${channel['key']}'),
                  onSelected: (selected) => setState(() {
                    final key = '${channel['key']}';
                    if (selected) {
                      _selectedChannels.add(key);
                    } else {
                      _selectedChannels.remove(key);
                    }
                  }),
                ),
            ],
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<bool?>(
            initialValue: _agreement,
            decoration: InputDecoration(
              labelText: l10n.enterpriseIsThereWrittenAgreement,
            ),
            items: [
              DropdownMenuItem<bool?>(
                value: null,
                child: Text(l10n.enterpriseNotAsked),
              ),
              DropdownMenuItem<bool?>(
                value: true,
                child: Text(l10n.enterpriseYesInWriting),
              ),
              DropdownMenuItem<bool?>(
                value: false,
                child: Text(l10n.enterpriseNoInformal),
              ),
            ],
            onChanged: (value) => setState(() => _agreement = value),
          ),

          const SizedBox(height: 12),
          Text(l10n.enterpriseMonthsTheySellIn, style: theme.textTheme.titleSmall),
          Text(
            // Recording the season is what stops a quiet month being read back
            // in the office as a failing business.
            l10n.enterpriseLeaveBlankIfAllYear,
            style: theme.textTheme.bodySmall,
          ),
          Wrap(
            spacing: 6,
            children: [
              for (var month = 1; month <= 12; month++)
                FilterChip(
                  label: Text(_monthLabels[month - 1]),
                  selected: _months.contains(month),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _months.add(month);
                    } else {
                      _months.remove(month);
                    }
                  }),
                ),
            ],
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _challenge,
            maxLines: 3,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: l10n.businessProfileBiggestProblemTheyFace,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.enterpriseSaving : l10n.enterpriseSave),
          ),
        ),
      ),
    );
  }
}

/// Picks a support need from the list the server holds.
///
/// A list rather than a text box, because "twelve groups need cold storage" is
/// a sentence a programme manager can act on and the same need typed twelve
/// ways is not.
class _SupportNeedSheet extends StatefulWidget {
  const _SupportNeedSheet({required this.needTypes});

  final List<Map<String, dynamic>> needTypes;

  @override
  State<_SupportNeedSheet> createState() => _SupportNeedSheetState();
}

class _SupportNeedSheetState extends State<_SupportNeedSheet> {
  String? _needKey;
  String _priority = 'MEDIUM';

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final type in widget.needTypes) {
      byCategory.putIfAbsent('${type['category']}', () => []).add(type);
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.enterpriseWhatDoesThisBusinessNeed,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in byCategory.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          entry.key.toLowerCase(),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final type in entry.value)
                            ChoiceChip(
                              label: Text('${type['title']}'),
                              selected: _needKey == '${type['key']}',
                              onSelected: (_) =>
                                  setState(() => _needKey = '${type['key']}'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.enterpriseHowUrgentIsIt, style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 6,
              children: [
                for (final priority in ['HIGH', 'MEDIUM', 'LOW'])
                  ChoiceChip(
                    label: Text(priority.toLowerCase()),
                    selected: _priority == priority,
                    onSelected: (_) => setState(() => _priority = priority),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // The group's own ranking, not the agent's. An agent ordering
              // somebody else's problems is a different measurement.
              l10n.enterpriseAskGroupToRank,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _needKey == null
                  ? null
                  : () => Navigator.of(context)
                      .pop({'needKey': _needKey!, 'priority': _priority}),
              child: Text(l10n.enterpriseAdd),
            ),
          ],
        ),
      ),
    );
  }
}
