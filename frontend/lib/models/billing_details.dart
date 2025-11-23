class BillingDetails {
  final String bookingId;
  final double currentCharge;
  final double cleaningCharge;
  final double vesselCharge;
  final double functionHallCharge;
  final double diningHallCharge;
  final double groceryCharge;
  final double vegetableCharge;
  final double morningFood;
  final double afternoonFood;
  final double nightFood;
  final int cylinderQuantity;
  final double cylinderAmount;

  BillingDetails({
    required this.bookingId,
    this.currentCharge = 0,
    this.cleaningCharge = 0,
    this.vesselCharge = 0,
    this.functionHallCharge = 0,
    this.diningHallCharge = 0,
    this.groceryCharge = 0,
    this.vegetableCharge = 0,
    this.morningFood = 0,
    this.afternoonFood = 0,
    this.nightFood = 0,
    this.cylinderQuantity = 0,
    this.cylinderAmount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'current_charge': currentCharge,
      'cleaning_charge': cleaningCharge,
      'vessel_charge': vesselCharge,
      'function_hall_charge': functionHallCharge,
      'dining_hall_charge': diningHallCharge,
      'grocery_charge': groceryCharge,
      'vegetable_charge': vegetableCharge,
      'morning_food': morningFood,
      'afternoon_food': afternoonFood,
      'night_food': nightFood,
      'cylinder_quantity': cylinderQuantity,
      'cylinder_amount': cylinderAmount,
    };
  }

  factory BillingDetails.fromJson(Map<String, dynamic> json) {
    return BillingDetails(
      bookingId: json['booking_id'] as String,
      currentCharge: _parseDouble(json['current_charge']),
      cleaningCharge: _parseDouble(json['cleaning_charge']),
      vesselCharge: _parseDouble(json['vessel_charge']),
      functionHallCharge: _parseDouble(json['function_hall_charge']),
      diningHallCharge: _parseDouble(json['dining_hall_charge']),
      groceryCharge: _parseDouble(json['grocery_charge']),
      vegetableCharge: _parseDouble(json['vegetable_charge']),
      morningFood: _parseDouble(json['morning_food']),
      afternoonFood: _parseDouble(json['afternoon_food']),
      nightFood: _parseDouble(json['night_food']),
      cylinderQuantity: _parseInt(json['cylinder_quantity']),
      cylinderAmount: _parseDouble(json['cylinder_amount']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  BillingDetails copyWith({
    String? bookingId,
    double? currentCharge,
    double? cleaningCharge,
    double? vesselCharge,
    double? functionHallCharge,
    double? diningHallCharge,
    double? groceryCharge,
    double? vegetableCharge,
    double? morningFood,
    double? afternoonFood,
    double? nightFood,
    int? cylinderQuantity,
    double? cylinderAmount,
  }) {
    return BillingDetails(
      bookingId: bookingId ?? this.bookingId,
      currentCharge: currentCharge ?? this.currentCharge,
      cleaningCharge: cleaningCharge ?? this.cleaningCharge,
      vesselCharge: vesselCharge ?? this.vesselCharge,
      functionHallCharge: functionHallCharge ?? this.functionHallCharge,
      diningHallCharge: diningHallCharge ?? this.diningHallCharge,
      groceryCharge: groceryCharge ?? this.groceryCharge,
      vegetableCharge: vegetableCharge ?? this.vegetableCharge,
      morningFood: morningFood ?? this.morningFood,
      afternoonFood: afternoonFood ?? this.afternoonFood,
      nightFood: nightFood ?? this.nightFood,
      cylinderQuantity: cylinderQuantity ?? this.cylinderQuantity,
      cylinderAmount: cylinderAmount ?? this.cylinderAmount,
    );
  }
}

