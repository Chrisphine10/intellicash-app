import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/membership.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// People who have asked to join the group, waiting on an official's answer.
class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  List<JoinRequest> _requests = const [];
  bool _loading = true;
  String? _error;

  /// The request currently being answered, so only its own buttons lock.
  String? _deciding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// [quiet] refreshes after a decision without flashing the whole list back
  /// to a spinner.
  Future<void> _load({bool quiet = false}) async {
    final connection = context.read<ConnectionProvider>();
    if (!quiet) setState(() => _loading = true);
    try {
      final requests = await connection.api.joinRequests(widget.groupId);
      if (mounted) {
        setState(() {
          _requests = requests;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load join requests.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(JoinRequest request) async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Let ${request.requestedName} join?',
            style: const TextStyle(fontSize: 17)),
        content: Text(
          // A phone number is whatever the person typed at sign-up; nothing
          // checks that it is theirs. When it matches the roster, accepting
          // hands over that member's savings, so say whose.
          request.takesOverExistingRecords
              ? '${request.requestedName} gave a phone number that is already '
                  'on the register for ${request.willLinkToMemberName}.\n\n'
                  'If you accept, this phone will be able to see and use '
                  '${request.willLinkToMemberName}\'s savings and loan '
                  'records. Only accept if you know it is the same person.'
              : '${request.requestedName} will become a member of ${_groupName()}. '
                  'They will be able to see the group\'s savings, loans and '
                  'meeting records, and take part in group business.\n\n'
                  'Only approve someone the group knows.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: request.takesOverExistingRecords
                ? FilledButton.styleFrom(backgroundColor: AppColors.pending)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(request.takesOverExistingRecords
                ? 'Yes, same person'
                : 'Yes, let them in'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _decide(
      request,
      approve: true,
      // Echoes back the member shown above, so the server refuses a handover
      // this official was never shown.
      confirmMemberId: request.willLinkToMemberId,
    );
  }

  Future<void> _decline(JoinRequest request) async {
    final l10n = L10n.of(context);
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Decline ${request.requestedName}?',
            style: const TextStyle(fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.joinRequestsTheyWillNotBeAddedTo,
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reason,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l10n.joinRequestsReasonOptional,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.defaulted,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.joinRequestsDecline),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _decide(request, approve: false, notes: reason.text);
    }
    reason.dispose();
  }

  Future<void> _decide(
    JoinRequest request, {
    required bool approve,
    String? notes,
    String? confirmMemberId,
  }) async {
    final connection = context.read<ConnectionProvider>();
    setState(() => _deciding = request.id);
    try {
      final result = await connection.api.decideJoinRequest(
        widget.groupId,
        request.id,
        approve: approve,
        notes: notes,
        confirmMemberId: confirmMemberId,
      );
      if (!mounted) return;
      if (!approve) {
        showAppSnack(context, '${request.requestedName} was declined.');
      } else if (result['matchedExistingMember'] == true) {
        // Savings recorded before the person had a login are common; saying
        // so stops the "where is my money?" question at the next meeting.
        showAppSnack(
          context,
          '${request.requestedName} is now a member. Their existing savings '
          'records were matched to them.',
        );
      } else {
        showAppSnack(
          context,
          '${request.requestedName} was added as a new member.',
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // A 409 means three quite different things here, and telling an official
      // "someone else answered" when the real problem is a name clash would
      // send them looking in the wrong place.
      final l10n = L10n.of(context);
      final message = switch (e.code) {
        'ALREADY_DECIDED' => 'Another official already answered this request.',
        // The list this screen is showing is out of date.
        'CONFIRM_EXISTING_MEMBER' => l10n.joinRequestsThisListIsOutOfDate,
        'MEMBER_ALREADY_LINKED' => e.message,
        _ => 'Could not send your answer. Try again.',
      };
      final routine = e.code == 'ALREADY_DECIDED';
      showAppSnack(context, message, error: !routine);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Could not send your answer. Try again.',
          error: true);
    } finally {
      if (mounted) setState(() => _deciding = null);
    }
    if (mounted) await _load(quiet: true);
  }

  /// Only name the group when the loaded one is the group on screen.
  String _groupName() {
    final group = context.read<ConnectionProvider>().selectedGroup;
    return group?.id == widget.groupId ? group!.name : 'this group';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final group = connection.selectedGroup;
    final pending = _requests.where((r) => r.isPending).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinRequestsJoinRequests)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Card(
              color: AppColors.surfaceRaised,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt,
                        size: 22, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.joinRequestsPeopleAskingToJoin,
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(
                            group?.id == widget.groupId
                                ? group!.name
                                : 'Your group',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: 'Couldn\'t load',
                  message: _error!,
                ),
              )
            else if (_requests.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.how_to_reg_outlined,
                  title: l10n.joinRequestsNoOneIsWaiting,
                  message: l10n.joinRequestsWhenSomeoneAsksToJoinYour,
                ),
              )
            else ...[
              SectionLabel(pending == 1
                  ? '1 waiting for your answer'
                  : '$pending waiting for your answer'),
              for (final request in _requests)
                _RequestCard(
                  request: request,
                  busy: _deciding == request.id,
                  onApprove: () => _approve(request),
                  onDecline: () => _decline(request),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  final JoinRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  /// Officials weigh a request partly by how long it has sat unanswered.
  static String _waited(DateTime? at) {
    if (at == null) return 'Just now';
    final since = DateTime.now().difference(at);
    if (since.inMinutes < 1) return 'Just now';
    if (since.inMinutes < 60) return '${since.inMinutes} min ago';
    if (since.inHours < 24) {
      return '${since.inHours} hour${since.inHours == 1 ? '' : 's'} ago';
    }
    if (since.inDays < 30) {
      return '${since.inDays} day${since.inDays == 1 ? '' : 's'} ago';
    }
    return Formatters.shortDate(at.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: MemberAvatar(request.requestedName),
            title: Text(
              request.requestedName,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${request.phone} · asked ${_waited(request.createdAt)}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          if (request.isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.defaulted,
                        side: BorderSide(
                            color: AppColors.defaulted.withValues(alpha: 0.4)),
                        minimumSize: const Size(0, 38),
                      ),
                      onPressed: busy ? null : onDecline,
                      child: Text(l10n.joinRequestsDecline),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38)),
                      onPressed: busy ? null : onApprove,
                      child: busy
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : Text(l10n.joinRequestsApprove),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  request.status == 'APPROVED'
                      ? 'Already approved'
                      : 'Already declined',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
