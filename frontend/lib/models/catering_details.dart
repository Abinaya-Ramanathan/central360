class CateringDetails {
  final String bookingId;
  final String? deliveryLocation;
  final String? morningFoodMenu;
  final int morningFoodCount;
  final String? afternoonFoodMenu;
  final int afternoonFoodCount;
  final String? eveningFoodMenu;
  final int eveningFoodCount;

  CateringDetails({
    required this.bookingId,
    this.deliveryLocation,
    this.morningFoodMenu,
    this.morningFoodCount = 0,
    this.afternoonFoodMenu,
    this.afternoonFoodCount = 0,
    this.eveningFoodMenu,
    this.eveningFoodCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'delivery_location': deliveryLocation,
      'morning_food_menu': morningFoodMenu,
      'morning_food_count': morningFoodCount,
      'afternoon_food_menu': afternoonFoodMenu,
      'afternoon_food_count': afternoonFoodCount,
      'evening_food_menu': eveningFoodMenu,
      'evening_food_count': eveningFoodCount,
    };
  }

  factory CateringDetails.fromJson(Map<String, dynamic> json) {
    return CateringDetails(
      bookingId: json['booking_id'] as String,
      deliveryLocation: json['delivery_location'] as String?,
      morningFoodMenu: json['morning_food_menu'] as String?,
      morningFoodCount: _parseInt(json['morning_food_count']),
      afternoonFoodMenu: json['afternoon_food_menu'] as String?,
      afternoonFoodCount: _parseInt(json['afternoon_food_count']),
      eveningFoodMenu: json['evening_food_menu'] as String?,
      eveningFoodCount: _parseInt(json['evening_food_count']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  CateringDetails copyWith({
    String? bookingId,
    String? deliveryLocation,
    String? morningFoodMenu,
    int? morningFoodCount,
    String? afternoonFoodMenu,
    int? afternoonFoodCount,
    String? eveningFoodMenu,
    int? eveningFoodCount,
  }) {
    return CateringDetails(
      bookingId: bookingId ?? this.bookingId,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      morningFoodMenu: morningFoodMenu ?? this.morningFoodMenu,
      morningFoodCount: morningFoodCount ?? this.morningFoodCount,
      afternoonFoodMenu: afternoonFoodMenu ?? this.afternoonFoodMenu,
      afternoonFoodCount: afternoonFoodCount ?? this.afternoonFoodCount,
      eveningFoodMenu: eveningFoodMenu ?? this.eveningFoodMenu,
      eveningFoodCount: eveningFoodCount ?? this.eveningFoodCount,
    );
  }
}

