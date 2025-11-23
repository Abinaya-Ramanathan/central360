class CreditDetails {
  final int? id;
  final String sectorCode;
  final String name;
  final String? phoneNumber;
  final String? address;
  final String? purchaseDetails;
  final double creditAmount;
  final double amountSettled;
  final DateTime creditDate;

  CreditDetails({
    this.id,
    required this.sectorCode,
    required this.name,
    this.phoneNumber,
    this.address,
    this.purchaseDetails,
    this.creditAmount = 0,
    this.amountSettled = 0,
    required this.creditDate,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'sector_code': sectorCode,
      'name': name,
      'phone_number': phoneNumber,
      'address': address,
      'purchase_details': purchaseDetails,
      'credit_amount': creditAmount,
      'amount_settled': amountSettled,
      'credit_date': creditDate.toIso8601String().split('T')[0],
    };
  }

  factory CreditDetails.fromJson(Map<String, dynamic> json) {
    return CreditDetails(
      id: _parseIdFromDynamic(json['id']),
      sectorCode: json['sector_code'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String?,
      address: json['address'] as String?,
      purchaseDetails: json['purchase_details'] as String?,
      creditAmount: _parseDouble(json['credit_amount']),
      amountSettled: _parseDouble(json['amount_settled']),
      creditDate: DateTime.parse(json['credit_date'] as String),
    );
  }

  static int? _parseIdFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  CreditDetails copyWith({
    int? id,
    String? sectorCode,
    String? name,
    String? phoneNumber,
    String? address,
    String? purchaseDetails,
    double? creditAmount,
    double? amountSettled,
    DateTime? creditDate,
  }) {
    return CreditDetails(
      id: id ?? this.id,
      sectorCode: sectorCode ?? this.sectorCode,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      purchaseDetails: purchaseDetails ?? this.purchaseDetails,
      creditAmount: creditAmount ?? this.creditAmount,
      amountSettled: amountSettled ?? this.amountSettled,
      creditDate: creditDate ?? this.creditDate,
    );
  }
}

