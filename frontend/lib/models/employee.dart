class Employee {
  final String id;
  final String name;
  final String contact;
  final String contact2; // Second phone number
  final String address;
  final String bankDetails;
  final String sector;
  final String role;
  final double dailySalary;
  final double weeklySalary;
  final double monthlySalary;
  final DateTime? joiningDate; // Optional - can be null if only year is selected
  final int? joiningYear; // Optional - can be used if only year is selected

  Employee({
    required this.id,
    required this.name,
    required this.contact,
    this.contact2 = '',
    this.address = '',
    this.bankDetails = '',
    required this.sector,
    this.role = '',
    this.dailySalary = 0.0,
    this.weeklySalary = 0.0,
    this.monthlySalary = 0.0,
    this.joiningDate,
    this.joiningYear,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact': contact,
      'contact2': contact2,
      'address': address,
      'bank_details': bankDetails,
      'sector': sector,
      'role': role,
      'daily_salary': dailySalary,
      'weekly_salary': weeklySalary,
      'monthly_salary': monthlySalary,
      'joining_date': joiningDate?.toIso8601String().split('T')[0],
      'joining_year': joiningYear,
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert salary values (handles both String and num)
    double parseSalary(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    // Helper function to safely parse joining year
    int? parseJoiningYear(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed;
      }
      return null;
    }

    return Employee(
      id: json['id'].toString(),
      name: json['name'] as String,
      contact: json['contact'] as String,
      contact2: json['contact2'] as String? ?? '',
      address: json['address'] as String? ?? '',
      bankDetails: json['bank_details'] as String? ?? '',
      sector: json['sector'] as String,
      role: json['role'] as String? ?? '',
      dailySalary: parseSalary(json['daily_salary']),
      weeklySalary: parseSalary(json['weekly_salary']),
      monthlySalary: parseSalary(json['monthly_salary']),
      joiningDate: json['joining_date'] != null
          ? DateTime.parse(json['joining_date'] as String)
          : null,
      joiningYear: parseJoiningYear(json['joining_year']),
    );
  }
}

