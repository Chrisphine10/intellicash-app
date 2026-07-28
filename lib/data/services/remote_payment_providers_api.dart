import '../../core/network/api_client.dart';

/// Where a group's collections are paid.
///
/// A group with its own M-Pesa till or Paystack account uses it; a group that
/// configures nothing collects into the platform's account, which is a valid
/// and common choice rather than an error state.
///
/// The backend NEVER returns secret values — it reports them as set. So this
/// model deliberately has no field that could hold a passkey: what comes back
/// is presence, not the credential.
class GroupPaymentProvider {
  const GroupPaymentProvider({
    required this.provider,
    required this.configured,
    required this.enabled,
    required this.mode,
    required this.values,
    required this.missingKeys,
    this.credentialsUpdatedAt,
  });

  /// "MPESA_DARAJA" | "PAYSTACK". M-Pesa Classic never appears: it has no
  /// credentials because the member types the transaction code in by hand.
  final String provider;

  /// True when this group collects into its OWN account.
  final bool configured;
  final bool enabled;
  final String mode;

  /// Key -> readable value, or the sentinel `__set__` for a stored secret,
  /// or null when unset.
  final Map<String, String?> values;

  /// Keys still needed. While this is non-empty the group keeps using the
  /// platform's account, however "configured" it looks.
  final List<String> missingKeys;

  final DateTime? credentialsUpdatedAt;

  static const secretSentinel = '__set__';

  bool isSecretSet(String key) => values[key] == secretSentinel;
  bool get isComplete => configured && missingKeys.isEmpty;

  String get label => switch (provider) {
        'MPESA_DARAJA' => 'M-Pesa (Daraja)',
        'PAYSTACK' => 'Paystack',
        _ => provider,
      };

  factory GroupPaymentProvider.fromJson(Map<String, dynamic> j) {
    final rawValues = (j['values'] as Map?) ?? const {};
    return GroupPaymentProvider(
      provider: '${j['provider']}',
      configured: j['configured'] == true,
      enabled: j['enabled'] == true,
      mode: '${j['mode'] ?? 'SANDBOX'}',
      values: {
        for (final entry in rawValues.entries)
          '${entry.key}': entry.value == null ? null : '${entry.value}',
      },
      missingKeys: ((j['missingKeys'] as List?) ?? const [])
          .map((value) => '$value')
          .toList(growable: false),
      credentialsUpdatedAt: j['credentialsUpdatedAt'] == null
          ? null
          : DateTime.tryParse('${j['credentialsUpdatedAt']}'),
    );
  }
}

class GroupPaymentProviders {
  const GroupPaymentProviders({
    required this.groupName,
    required this.providers,
    required this.canConfigure,
  });

  final String groupName;
  final List<GroupPaymentProvider> providers;

  /// False for anyone who may read the group but must not redirect its money —
  /// village agents, for instance.
  final bool canConfigure;

  factory GroupPaymentProviders.fromJson(Map<String, dynamic> j) {
    return GroupPaymentProviders(
      groupName: '${(j['group'] as Map?)?['name'] ?? ''}',
      providers: ((j['providers'] as List?) ?? const [])
          .map((entry) => GroupPaymentProvider.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList(growable: false),
      canConfigure: j['canConfigure'] == true,
    );
  }
}

class RemotePaymentProvidersApi {
  RemotePaymentProvidersApi(this._client);

  final ApiClient _client;

  Future<GroupPaymentProviders> list(String groupId) async {
    final data = await _client.getData('/groups/$groupId/payment-providers');
    return GroupPaymentProviders.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Saves only the fields supplied. The backend merges, so correcting a
  /// shortcode does not require re-typing every secret.
  Future<GroupPaymentProvider> save({
    required String groupId,
    required String provider,
    required Map<String, String> credentials,
    bool enabled = true,
  }) async {
    final data = await _client.putData(
      '/groups/$groupId/payment-providers/$provider',
      body: {'credentials': credentials, 'enabled': enabled},
    );
    return GroupPaymentProvider.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Hands the group back to the platform's account.
  Future<void> revert({required String groupId, required String provider}) async {
    await _client.deleteData('/groups/$groupId/payment-providers/$provider');
  }
}
