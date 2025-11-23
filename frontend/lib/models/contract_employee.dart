class ContractEmployee {
  final String id;
  final String name;
  final int membersCount;
  final String reason;
  final double salaryPerCount;
  final double totalSalary;
  final DateTime date;

  ContractEmployee({
    required this.id,
    required this.name,
    required this.membersCount,
    required this.reason,
    required this.salaryPerCount,
    required this.totalSalary,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'members_count': membersCount,
      'reason': reason,
      'salary_per_count': salaryPerCount,
      'total_salary': totalSalary,
      'date': date.toIso8601String().split('T')[0],
    };
  }

  factory ContractEmployee.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert salary values
    double parseSalary(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    // Helper function to safely parse members count
    int parseMembersCount(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? 0;
      }
      return 0;
    }

    return ContractEmployee(
      id: json['id'].toString(),
      name: json['name'] as String,
      membersCount: parseMembersCount(json['members_count']),
      reason: json['reason'] as String? ?? '',
      salaryPerCount: parseSalary(json['salary_per_count']),
      totalSalary: parseSalary(json['total_salary']),
      date: DateTime.parse(json['date'] as String),
    );
  }

  ContractEmployee copyWith({
    String? id,
    String? name,
    int? membersCount,
    String? reason,
    double? salaryPerCount,
    double? totalSalary,
    DateTime? date,
  }) {
    return ContractEmployee(
      id: id ?? this.id,
      name: name ?? this.name,
      membersCount: membersCount ?? this.membersCount,
      reason: reason ?? this.reason,
      salaryPerCount: salaryPerCount ?? this.salaryPerCount,
      totalSalary: totalSalary ?? this.totalSalary,
      date: date ?? this.date,
    );
  }
}

