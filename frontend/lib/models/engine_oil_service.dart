class EngineOilService {
  final int? id;
  final String? sectorCode;
  final String vehicleName;
  final String model;
  final String servicePartName;
  final DateTime serviceDate;
  final int? serviceInKms;
  final int? serviceInHrs;
  final DateTime? nextServiceDate;

  EngineOilService({
    this.id,
    this.sectorCode,
    required this.vehicleName,
    required this.model,
    required this.servicePartName,
    required this.serviceDate,
    this.serviceInKms,
    this.serviceInHrs,
    this.nextServiceDate,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (sectorCode != null) 'sector_code': sectorCode,
      'vehicle_name': vehicleName,
      'model': model,
      'service_part_name': servicePartName,
      'service_date': serviceDate.toIso8601String().split('T')[0],
      'service_in_kms': serviceInKms,
      'service_in_hrs': serviceInHrs,
      'next_service_date': nextServiceDate?.toIso8601String().split('T')[0],
    };
  }

  factory EngineOilService.fromJson(Map<String, dynamic> json) {
    return EngineOilService(
      id: _parseId(json['id']),
      sectorCode: json['sector_code'] as String?,
      vehicleName: json['vehicle_name'] as String,
      model: json['model'] as String,
      servicePartName: json['service_part_name'] as String,
      serviceDate: DateTime.parse(json['service_date'] as String),
      serviceInKms: _parseInt(json['service_in_kms']),
      serviceInHrs: _parseInt(json['service_in_hrs']),
      nextServiceDate: json['next_service_date'] != null ? DateTime.parse(json['next_service_date'] as String) : null,
    );
  }

  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

