import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/meeting_unlock.dart';
import '../../data/models/member.dart';
import '../../data/repositories/id_map_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// The 3-key gate before a meeting starts: three officials — or most of the
/// members — each turn their key. **Online** (and when the group is backed up
/// to the cloud) a one-time code is texted to the member's phone and checked
/// by the server. **Offline** the member's saved PIN on this phone is used
/// instead. Pops with the list of verified member ids once quorum is reached.
class ThreeKeyUnlockScreen extends StatefulWidget {
  const ThreeKeyUnlockScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<ThreeKeyUnlockScreen> createState() => _ThreeKeyUnlockScreenState();
}

class _ThreeKeyUnlockScreenState extends State<ThreeKeyUnlockScreen> {
  final _members = <Member>[];
  final Set<String> _verified = {};
  bool _loading = true;

  // Reads raw members (with PIN state) straight from the local database —
  // the shared MemberProvider only exposes the financials view.
  final _repository = MemberRepository(AppDatabase.instance);
  final _idMap = IdMapRepository(AppDatabase.instance);

  /// Backend ids, present only when this group has been backed up online.
  String? _remoteGroupId;
  Map<String, String> _remoteMemberIds = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members = await _repository.membersForGroup(widget.groupId);
    final remoteGroupId =
        await _idMap.remoteId(MapEntity.group, widget.groupId);
    final memberMappings = await _idMap.mappings(MapEntity.member);
    if (!mounted) return;
    setState(() {
      _members
        ..clear()
        ..addAll(members);
      _remoteGroupId = remoteGroupId;
      _remoteMemberIds = memberMappings;
      _loading = false;
    });
  }

  /// Online OTP applies when the server is reachable AND this member exists
  /// on it (the group has been backed up). Anything else uses the saved PIN.
  bool _otpAvailable(ConnectionProvider connection, Member member) {
    return connection.isConnected &&
        _remoteGroupId != null &&
        _remoteMemberIds.containsKey(member.id);
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final online = connection.isConnected && _remoteGroupId != null;
    final status = MeetingUnlock.evaluate(
      activeMembers: _members,
      verifiedMemberIds: _verified,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Unlock Meeting')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Card(
                  color: AppColors.primaryTint,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.key_outlined,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The meeting opens when '
                            '${MeetingUnlock.officialsRequired} officials — '
                            'or ${status.memberQuorum} members — each turn '
                            'their key.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(online ? Icons.wifi : Icons.wifi_off,
                        size: 14,
                        color: online
                            ? AppColors.primary
                            : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      online
                          ? 'Online — codes are sent to members\' phones'
                          : 'Offline — saved PINs on this phone are used',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(status.progressLabel,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: status.satisfied
                              ? AppColors.primary
                              : AppColors.textSecondary)),
                ),
                const SectionLabel('Members'),
                for (final member in _members)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      leading: Icon(
                        _verified.contains(member.id)
                            ? Icons.check_circle
                            : member.isOfficial
                                ? Icons.key_outlined
                                : Icons.person_outline,
                        size: 22,
                        color: _verified.contains(member.id)
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      title: Text(member.name,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${member.role.label}'
                        '${_otpAvailable(connection, member) ? ' · code by SMS' : member.hasPin ? '' : ' · no PIN yet'}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing: _verified.contains(member.id)
                          ? Text('Verified',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary))
                          : const Icon(Icons.chevron_right, size: 20),
                      onTap: _verified.contains(member.id)
                          ? null
                          : () => _turnKey(member),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: status.satisfied
                      ? () => Navigator.of(context).pop(_verified.toList())
                      : null,
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: Text(status.satisfied
                      ? 'Open the Meeting'
                      : 'Waiting for keys…'),
                ),
              ],
            ),
    );
  }

  Future<void> _turnKey(Member member) async {
    final connection = context.read<ConnectionProvider>();
    if (_otpAvailable(connection, member)) {
      final result = await showModalBottomSheet<Object>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _OtpSheet(
          member: member,
          groupRemoteId: _remoteGroupId!,
          memberRemoteId: _remoteMemberIds[member.id]!,
          connection: connection,
        ),
      );
      if (!mounted) return;
      if (result == true) {
        setState(() => _verified.add(member.id));
        return;
      }
      if (result != _kUsePinFallback) return;
      // Fall through to the PIN sheet below.
    }
    await _enterPin(member);
  }

  Future<void> _enterPin(Member member) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PinSheet(
        member: member,
        onSetPin: (hash) async {
          await _repository.setPinHash(member.id, hash);
        },
      ),
    );
    if (result == true) {
      // Refresh so a just-set PIN shows up, then count the key.
      final members = await _repository.membersForGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(members);
        _verified.add(member.id);
      });
    }
  }
}

const _kUsePinFallback = 'use-pin';

/// Online key turn: the server texts the member a one-time code; entering it
/// verifies against the server. The saved-PIN path stays available in case
/// the SMS doesn't arrive.
class _OtpSheet extends StatefulWidget {
  const _OtpSheet({
    required this.member,
    required this.groupRemoteId,
    required this.memberRemoteId,
    required this.connection,
  });

  final Member member;
  final String groupRemoteId;
  final String memberRemoteId;
  final ConnectionProvider connection;

  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> {
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  bool _sent = false;
  String? _maskedPhone;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.member.name}\'s key',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            _sent
                ? 'A code was sent${_maskedPhone != null ? ' to $_maskedPhone' : ' to your phone'}. '
                    'Type it below to turn your key.'
                : 'We\'ll send a one-time code to your phone by SMS.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (!_sent)
            FilledButton.icon(
              onPressed: _sending ? null : _sendCode,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sms_outlined, size: 18),
              label: Text(_sending ? 'Sending…' : 'Send My Code'),
            )
          else ...[
            TextField(
              controller: _codeCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'One-time code',
                counterText: '',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _verifying ? null : _verify,
              child: Text(_verifying ? 'Checking…' : 'Turn Key'),
            ),
            TextButton(
              onPressed: _sending ? null : _sendCode,
              child: const Text('Send a new code'),
            ),
          ],
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_kUsePinFallback),
              child: const Text('No SMS? Use my saved PIN instead'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final masked = await widget.connection.api
          .sendMemberOtp(widget.groupRemoteId, widget.memberRemoteId);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _maskedPhone = masked;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      if (mounted && !_sent) {
        showAppSnack(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Type the code from the SMS.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final valid = await widget.connection.api.verifyMemberCredential(
          widget.groupRemoteId, widget.memberRemoteId, code);
      if (!mounted) return;
      if (valid) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'That code is wrong or has expired.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }
}

/// Enter (or first set) a member's 6-digit PIN. Pops true when the PIN is
/// verified — setting a fresh PIN counts as this member's key too.
class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.member, required this.onSetPin});

  final Member member;
  final Future<void> Function(String pinHash) onSetPin;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;

  bool get _isFirstTime => !widget.member.hasPin;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isFirstTime
                ? 'Set a PIN for ${widget.member.name}'
                : '${widget.member.name}\'s PIN',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            _isFirstTime
                ? 'Choose a secret 6-digit PIN. Only you should know it — '
                    'it is your key to the group\'s meetings.'
                : 'Enter your secret 6-digit PIN to turn your key.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pinCtrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            // Four to set; up to six to enter, because that is what members who
            // set a PIN before this change are still holding.
            maxLength: _isFirstTime
                ? MeetingUnlock.pinLength
                : MeetingUnlock.legacyPinLength,
            decoration: InputDecoration(
              labelText: _isFirstTime ? 'New PIN' : 'PIN',
              counterText: '',
              errorText: _error,
            ),
          ),
          if (_isFirstTime) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: MeetingUnlock.pinLength,
              decoration: const InputDecoration(
                labelText: 'Repeat PIN',
                counterText: '',
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: Text(_isFirstTime ? 'Set PIN & Turn Key' : 'Turn Key'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    if (!MeetingUnlock.isValidPin(pin)) {
      setState(() => _error = 'The PIN must be exactly 6 digits.');
      return;
    }
    if (_isFirstTime) {
      if (_confirmCtrl.text.trim() != pin) {
        setState(() => _error = 'The two PINs don\'t match.');
        return;
      }
      await widget.onSetPin(MeetingUnlock.hashPin(widget.member.id, pin));
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    if (!MeetingUnlock.isEnterablePin(pin)) {
      setState(() => _error = 'Enter your PIN.');
      return;
    }
    if (!MeetingUnlock.verifyPin(widget.member, pin)) {
      setState(() => _error = 'Wrong PIN. Try again.');
      return;
    }
    /*
     * Upgrade the stored hash the moment the PIN is known to be right.
     *
     * The PIN itself is never stored, so a hash written under the old SHA-256
     * scheme can only be re-hashed here — at the one instant the plaintext is
     * in hand and proven correct. Left alone it would stay a fast hash of a
     * four-digit secret for the life of the phone.
     */
    if (MeetingUnlock.needsRehash(widget.member.pinHash)) {
      await widget.onSetPin(MeetingUnlock.hashPin(widget.member.id, pin));
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}
