import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/remote/membership.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// The group's invite link and QR code.
///
/// A secretary at a meeting holds this up and people scan it. It replaces the
/// old route in, which was: already have an account, know the group code, and
/// type it correctly.
///
/// The link does not let anybody in. It creates their account and files a
/// request that an official still has to approve. That is said on this screen
/// as well as on the page the link opens, because the person sharing it needs
/// to know what they are handing out.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  GroupJoinLink? _link;
  bool _loading = true;
  bool _rotating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final l10n = L10n.of(context);
    final connection = context.read<ConnectionProvider>();
    setState(() => _loading = true);
    try {
      final link = await connection.api.joinLink(widget.groupId);
      if (mounted) setState(() => _error = null);
      if (mounted) setState(() => _link = link);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.inviteCouldNotLoad);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    final link = _link;
    if (link == null) return;
    final l10n = L10n.of(context);
    // Same call the report screens use, so one share sheet behaves the same
    // way everywhere in the app.
    await Share.share(l10n.inviteShareMessage(link.groupName, link.url));
  }

  Future<void> _copy() async {
    final link = _link;
    if (link == null) return;
    final l10n = L10n.of(context);
    await Clipboard.setData(ClipboardData(text: link.url));
    if (mounted) showAppSnack(context, l10n.inviteCopied);
  }

  /// Reissue, killing every poster and forwarded message carrying the old one.
  Future<void> _rotate() async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inviteNewLinkTitle, style: const TextStyle(fontSize: 17)),
        content: Text(l10n.inviteNewLinkBody, style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.pending),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.inviteNewLinkConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _rotating = true);
    try {
      final link = await context.read<ConnectionProvider>().api.rotateJoinLink(widget.groupId);
      if (!mounted) return;
      setState(() => _link = link);
      showAppSnack(context, l10n.inviteNewLinkDone);
    } catch (_) {
      if (mounted) showAppSnack(context, l10n.inviteCouldNotLoad, error: true);
    } finally {
      if (mounted) setState(() => _rotating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final link = _link;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null || link == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: l10n.joinRequestsCouldNotLoadTitle,
                  message: _error ?? l10n.inviteCouldNotLoad,
                ),
              )
            else ...[
              _QrCard(link: link),
              const SizedBox(height: 16),

              // The address itself, selectable, for somebody reading it out or
              // typing it into a browser that cannot scan.
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.inviteLinkLabel,
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: 6),
                      SelectableText(
                        link.url,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(l10n.inviteCopy),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(l10n.inviteShare),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 46)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // What sharing this actually does. The person handing it out is
              // the one who needs to understand that it grants nothing.
              Card(
                color: AppColors.surfaceRaised,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_outlined,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.inviteApprovalNotice,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              TextButton.icon(
                onPressed: _rotating ? null : _rotate,
                icon: const Icon(Icons.autorenew_rounded, size: 18),
                label: Text(_rotating ? l10n.inviteNewLinkWorking : l10n.inviteNewLink),
                style: TextButton.styleFrom(foregroundColor: AppColors.defaulted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The QR itself, on a white card whatever the app theme is.
///
/// White is not decoration here. A scanner reads dark modules against a light
/// ground, and a QR rendered on a dark surface in dark mode simply does not
/// scan on many phones. The quiet zone around it is part of the spec too, so
/// the padding is doing work rather than styling.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.link});

  final GroupJoinLink link;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          children: [
            Text(
              link.groupName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10261A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.inviteScanToJoin,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B60)),
            ),
            const SizedBox(height: 18),
            Center(
              child: QrImageView(
                data: link.url,
                version: QrVersions.auto,
                size: 244,
                backgroundColor: Colors.white,
                // High correction, because the logo in the middle covers real
                // modules. At the default level a centred mark can push a code
                // past what a scanner can rebuild.
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                embeddedImage: const AssetImage('assets/branding/logo_mark.png'),
                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(46, 46)),
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF10261A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF10261A),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'INTELLI-CASH',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
