class DriverLicense {
  final int? id;
  final String? sectorCode;
  final String driverName;
  final String licenseNumber;
  final DateTime expiryDate;

  DriverLicense({
    this.id,
    this.sectorCode,
    required this.driverName,
    required this.licenseNumber,
    required this.expiryDate,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (sectorCode != null) 'sector_code': sectorCode,
      'driver_name': driverName,
      'license_number': licenseNumber,
      'expiry_date': expiryDate.toIso8601String().split('T')[0],
    };
  }

  factory DriverLicense.fromJson(Map<String, dynamic> json) {
    return DriverLicense(
      id: _parseId(json['id']),
      sectorCode: json['sector_code'] as String?,
      driverName: json['driver_name'] as String,
      licenseNumber: json['license_number'] as String,
      expiryDate: DateTime.parse(json['expiry_date'] as String),
    );
  }

  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

