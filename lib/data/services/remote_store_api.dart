import '../../core/network/api_client.dart';
import '../models/remote/store_models.dart';

/// Intelli-Store endpoints reachable with a `store:read`/`store:write`
/// credential. Browse the catalogue, book a credit request, and review your
/// own requests.
class RemoteStoreApi {
  RemoteStoreApi(this._client);

  final ApiClient _client;

  /// `GET /intelli-store/products` — the financed catalogue.
  Future<List<StoreProduct>> products() async {
    final list = await _client.getList('/intelli-store/products');
    return list
        .map((e) => StoreProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /programmes` — programmes a credit request can be booked against.
  Future<List<StoreProgramme>> programmes() async {
    final list = await _client.getList('/programmes');
    return list
        .map((e) => StoreProgramme.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /intelli-store/credit-requests` — request an item on credit.
  ///
  /// When [groupId] is set, the backend prices the purchase against that
  /// group's credit rating (deposit, interest and instalment count all
  /// follow the group's band) instead of the product's flat default.
  ///
  /// [meetingId] ties the purchase to the sitting where the group agreed it,
  /// so it shows up in that meeting's record. The backend only accepts it
  /// alongside a [groupId], and only for a meeting of that same group.
  Future<StoreCreditRequest> createCreditRequest({
    required String productId,
    required String programmeId,
    required String customerName,
    required String customerEmail,
    required String phoneNumber,
    required int quantity,
    String? groupId,
    String? groupName,
    String? county,
    String? notes,
    String? meetingId,
  }) async {
    final data =
        await _client.postData('/intelli-store/credit-requests', body: {
      'productId': productId,
      'programmeId': programmeId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'phoneNumber': phoneNumber,
      'quantity': quantity,
      if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
      // Only meaningful for a group purchase; the backend rejects it otherwise.
      if (groupId != null &&
          groupId.isNotEmpty &&
          meetingId != null &&
          meetingId.isNotEmpty)
        'meetingId': meetingId,
      if (groupName != null && groupName.isNotEmpty) 'groupName': groupName,
      if (county != null && county.isNotEmpty) 'county': county,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return StoreCreditRequest.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /intelli-store/credit-requests` — the caller's own requests.
  Future<List<StoreCreditRequest>> myCreditRequests() async {
    final list = await _client.getList('/intelli-store/credit-requests');
    return list
        .map((e) => StoreCreditRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
