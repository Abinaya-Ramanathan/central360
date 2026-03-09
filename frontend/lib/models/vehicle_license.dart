import '../utils/format_utils.dart';

class VehicleLicense {
  final int? id;
  final String? sectorCode;
  final String name;
  final String model;
  final String registrationNumber;
  final DateTime? permitDate;
  final DateTime? insuranceDate;
  final DateTime? fitnessDate;
  final DateTime? pollutionDate;
  final DateTime? taxDate;

  VehicleLicense({
    this.id,
    this.sectorCode,
    required this.name,
    required this.model,
    required this.registrationNumber,
    this.permitDate,
    this.insuranceDate,
    this.fitnessDate,
    this.pollutionDate,
    this.taxDate,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (sectorCode != null) 'sector_code': sectorCode,
      'name': name,
      'model': model,
      'registration_number': registrationNumber,
      'permit_date': permitDate != null ? FormatUtils.formatDateForApi(permitDate!) : null,
      'insurance_date': insuranceDate != null ? FormatUtils.formatDateForApi(insuranceDate!) : null,
      'fitness_date': fitnessDate != null ? FormatUtils.formatDateForApi(fitnessDate!) : null,
      'pollution_date': pollutionDate != null ? FormatUtils.formatDateForApi(pollutionDate!) : null,
      'tax_date': taxDate != null ? FormatUtils.formatDateForApi(taxDate!) : null,
    };
  }

  factory VehicleLicense.fromJson(Map<String, dynamic> json) {
    return VehicleLicense(
      id: _parseId(json['id']),
      sectorCode: json['sector_code'] as String?,
      name: json['name'] as String,
      model: json['model'] as String,
      registrationNumber: json['registration_number'] as String,
      permitDate: json['permit_date'] != null ? DateTime.parse(json['permit_date'] as String) : null,
      insuranceDate: json['insurance_date'] != null ? DateTime.parse(json['insurance_date'] as String) : null,
      fitnessDate: json['fitness_date'] != null ? DateTime.parse(json['fitness_date'] as String) : null,
      pollutionDate: json['pollution_date'] != null ? DateTime.parse(json['pollution_date'] as String) : null,
      taxDate: json['tax_date'] != null ? DateTime.parse(json['tax_date'] as String) : null,
    );
  }

  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

