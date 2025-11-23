class ExpenseDetails {
  final String bookingId;
  final double masterSalary;
  final double cookingHelperSalary;
  final double externalCateringSalary;
  final double currentBill;
  final double cleaningBill;
  final double groceryBill;
  final double vegetableBill;
  final double cylinderAmount;
  final double morningFoodExpense;
  final double totalExpense;
  final double afternoonFoodExpense;
  final double eveningFoodExpense;
  final double vehicleExpense;
  final double packingItemsCharge;
  final String? details;

  ExpenseDetails({
    required this.bookingId,
    this.masterSalary = 0,
    this.cookingHelperSalary = 0,
    this.externalCateringSalary = 0,
    this.currentBill = 0,
    this.cleaningBill = 0,
    this.groceryBill = 0,
    this.vegetableBill = 0,
    this.cylinderAmount = 0,
    this.morningFoodExpense = 0,
    this.totalExpense = 0,
    this.afternoonFoodExpense = 0,
    this.eveningFoodExpense = 0,
    this.vehicleExpense = 0,
    this.packingItemsCharge = 0,
    this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'master_salary': masterSalary,
      'cooking_helper_salary': cookingHelperSalary,
      'external_catering_salary': externalCateringSalary,
      'current_bill': currentBill,
      'cleaning_bill': cleaningBill,
      'grocery_bill': groceryBill,
      'vegetable_bill': vegetableBill,
      'cylinder_amount': cylinderAmount,
      'morning_food_expense': morningFoodExpense,
      'total_expense': totalExpense,
      'afternoon_food_expense': afternoonFoodExpense,
      'evening_food_expense': eveningFoodExpense,
      'vehicle_expense': vehicleExpense,
      'packing_items_charge': packingItemsCharge,
      'details': details,
    };
  }

  factory ExpenseDetails.fromJson(Map<String, dynamic> json) {
    return ExpenseDetails(
      bookingId: json['booking_id'] as String,
      masterSalary: _parseDouble(json['master_salary']),
      cookingHelperSalary: _parseDouble(json['cooking_helper_salary']),
      externalCateringSalary: _parseDouble(json['external_catering_salary']),
      currentBill: _parseDouble(json['current_bill']),
      cleaningBill: _parseDouble(json['cleaning_bill']),
      groceryBill: _parseDouble(json['grocery_bill']),
      vegetableBill: _parseDouble(json['vegetable_bill']),
      cylinderAmount: _parseDouble(json['cylinder_amount']),
      morningFoodExpense: _parseDouble(json['morning_food_expense']),
      totalExpense: _parseDouble(json['total_expense']),
      afternoonFoodExpense: _parseDouble(json['afternoon_food_expense']),
      eveningFoodExpense: _parseDouble(json['evening_food_expense']),
      vehicleExpense: _parseDouble(json['vehicle_expense']),
      packingItemsCharge: _parseDouble(json['packing_items_charge']),
      details: json['details'] as String?,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  ExpenseDetails copyWith({
    String? bookingId,
    double? masterSalary,
    double? cookingHelperSalary,
    double? externalCateringSalary,
    double? currentBill,
    double? cleaningBill,
    double? groceryBill,
    double? vegetableBill,
    double? cylinderAmount,
    double? morningFoodExpense,
    double? totalExpense,
    double? afternoonFoodExpense,
    double? eveningFoodExpense,
    double? vehicleExpense,
    double? packingItemsCharge,
    String? details,
  }) {
    return ExpenseDetails(
      bookingId: bookingId ?? this.bookingId,
      masterSalary: masterSalary ?? this.masterSalary,
      cookingHelperSalary: cookingHelperSalary ?? this.cookingHelperSalary,
      externalCateringSalary: externalCateringSalary ?? this.externalCateringSalary,
      currentBill: currentBill ?? this.currentBill,
      cleaningBill: cleaningBill ?? this.cleaningBill,
      groceryBill: groceryBill ?? this.groceryBill,
      vegetableBill: vegetableBill ?? this.vegetableBill,
      cylinderAmount: cylinderAmount ?? this.cylinderAmount,
      morningFoodExpense: morningFoodExpense ?? this.morningFoodExpense,
      totalExpense: totalExpense ?? this.totalExpense,
      afternoonFoodExpense: afternoonFoodExpense ?? this.afternoonFoodExpense,
      eveningFoodExpense: eveningFoodExpense ?? this.eveningFoodExpense,
      vehicleExpense: vehicleExpense ?? this.vehicleExpense,
      packingItemsCharge: packingItemsCharge ?? this.packingItemsCharge,
      details: details ?? this.details,
    );
  }
}

