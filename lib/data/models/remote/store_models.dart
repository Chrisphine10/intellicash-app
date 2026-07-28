/// DTOs for the Intelli-Store module — a credit-financed general-products
/// marketplace (farm equipment, solar, electronics, household, business
/// equipment and more — not limited to agriculture, and not a retail POS).
/// Every product is priced by the buying group's credit rating. Money is
/// integer cents on the wire.
///
/// Shapes verified against the running API (2026-07-17).
library;

double _kes(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0) / 100;

int _toInt(Object? v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// A catalogue item financed on credit (`GET /intelli-store/products`).
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.imageUrl,
    this.sellerName,
    required this.price,
    required this.deposit,
    this.currency = 'KES',
    required this.inventoryCount,
    this.creditSummary,
    this.fulfilmentSummary,
  });

  final String id;
  final String name;
  final String category;
  final String? description;
  final String? imageUrl;
  final String? sellerName;
  final double price; // KES
  final double deposit; // KES
  final String currency;
  final int inventoryCount;
  final String? creditSummary;
  final String? fulfilmentSummary;

  bool get inStock => inventoryCount > 0;

  String get categoryLabel => category
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');

  factory StoreProduct.fromJson(Map<String, dynamic> j) {
    return StoreProduct(
      id: '${j['id']}',
      name: '${j['name'] ?? 'Product'}',
      category: '${j['category'] ?? ''}',
      description: j['description'] as String?,
      imageUrl: j['imageUrl'] as String?,
      sellerName: j['sellerName'] as String?,
      price: _kes(j['priceCents']),
      deposit: _kes(j['depositCents']),
      currency: '${j['currency'] ?? 'KES'}',
      inventoryCount: _toInt(j['inventoryCount']),
      creditSummary: j['creditSummary'] as String?,
      fulfilmentSummary: j['fulfilmentSummary'] as String?,
    );
  }
}

/// A programme a credit request is booked against (`GET /programmes`).
class StoreProgramme {
  const StoreProgramme({required this.id, required this.name});

  final String id;
  final String name;

  factory StoreProgramme.fromJson(Map<String, dynamic> j) =>
      StoreProgramme(id: '${j['id']}', name: '${j['name'] ?? 'Programme'}');
}

/// A submitted credit request (`GET/POST /intelli-store/credit-requests`).
class StoreCreditRequest {
  const StoreCreditRequest({
    required this.id,
    required this.status,
    required this.quantity,
    this.productName,
    this.customerName,
    this.createdAt,
  });

  final String id;
  final String status;
  final int quantity;
  final String? productName;
  final String? customerName;
  final DateTime? createdAt;

  factory StoreCreditRequest.fromJson(Map<String, dynamic> j) {
    final product = j['product'];
    return StoreCreditRequest(
      id: '${j['id']}',
      status: '${j['status'] ?? ''}',
      quantity: _toInt(j['quantity']),
      productName: product is Map ? product['name'] as String? : j['productName'] as String?,
      customerName: j['customerName'] as String?,
      createdAt: _date(j['createdAt']),
    );
  }
}
