class MahalBooking {
  final String? bookingId;
  final String sectorCode;
  final String mahalDetail;
  final DateTime eventDate;
  final String? eventTiming;
  final String? eventName;
  final String clientName;
  final String? clientPhone1;
  final String? clientPhone2;
  final String? clientAddress;
  final String? foodService;
  final double? advanceReceived;
  final double? quotedAmount;
  final double? amountReceived;
  final String? orderStatus;

  MahalBooking({
    this.bookingId,
    required this.sectorCode,
    required this.mahalDetail,
    required this.eventDate,
    this.eventTiming,
    this.eventName,
    required this.clientName,
    this.clientPhone1,
    this.clientPhone2,
    this.clientAddress,
    this.foodService,
    this.advanceReceived,
    this.quotedAmount,
    this.amountReceived,
    this.orderStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'sector_code': sectorCode,
      'mahal_detail': mahalDetail,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'event_timing': eventTiming,
      'event_name': eventName,
      'client_name': clientName,
      'client_phone1': clientPhone1,
      'client_phone2': clientPhone2,
      'client_address': clientAddress,
      'food_service': foodService,
      'advance_received': advanceReceived,
      'quoted_amount': quotedAmount,
      'amount_received': amountReceived,
      'order_status': orderStatus,
    };
  }

  factory MahalBooking.fromJson(Map<String, dynamic> json) {
    return MahalBooking(
      bookingId: json['booking_id'] as String?,
      sectorCode: json['sector_code'] as String,
      mahalDetail: json['mahal_detail'] as String,
      eventDate: DateTime.parse(json['event_date'] as String),
      eventTiming: json['event_timing'] as String?,
      eventName: json['event_name'] as String?,
      clientName: json['client_name'] as String,
      clientPhone1: json['client_phone1'] as String?,
      clientPhone2: json['client_phone2'] as String?,
      clientAddress: json['client_address'] as String?,
      foodService: json['food_service'] as String?,
      advanceReceived: _parseDouble(json['advance_received']),
      quotedAmount: _parseDouble(json['quoted_amount']),
      amountReceived: _parseDouble(json['amount_received']),
      orderStatus: json['order_status'] as String?,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  MahalBooking copyWith({
    String? bookingId,
    String? sectorCode,
    String? mahalDetail,
    DateTime? eventDate,
    String? eventTiming,
    String? eventName,
    String? clientName,
    String? clientPhone1,
    String? clientPhone2,
    String? clientAddress,
    String? foodService,
    double? advanceReceived,
    double? quotedAmount,
    double? amountReceived,
    String? orderStatus,
  }) {
    return MahalBooking(
      bookingId: bookingId ?? this.bookingId,
      sectorCode: sectorCode ?? this.sectorCode,
      mahalDetail: mahalDetail ?? this.mahalDetail,
      eventDate: eventDate ?? this.eventDate,
      eventTiming: eventTiming ?? this.eventTiming,
      eventName: eventName ?? this.eventName,
      clientName: clientName ?? this.clientName,
      clientPhone1: clientPhone1 ?? this.clientPhone1,
      clientPhone2: clientPhone2 ?? this.clientPhone2,
      clientAddress: clientAddress ?? this.clientAddress,
      foodService: foodService ?? this.foodService,
      advanceReceived: advanceReceived ?? this.advanceReceived,
      quotedAmount: quotedAmount ?? this.quotedAmount,
      amountReceived: amountReceived ?? this.amountReceived,
      orderStatus: orderStatus ?? this.orderStatus,
    );
  }
}

