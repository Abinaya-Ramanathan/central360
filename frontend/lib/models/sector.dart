class Sector {
  final String code;
  final String name;
  /// Optional parent sector code. When set, this sector is a sub-sector of the parent (e.g. SSCT under SSC).
  final String? parentCode;

  const Sector({required this.code, required this.name, this.parentCode});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'code': code, 'name': name};
    if (parentCode != null && parentCode!.isNotEmpty) {
      map['parent_sector_code'] = parentCode;
    }
    return map;
  }

  factory Sector.fromJson(Map<String, dynamic> json) {
    return Sector(
      code: json['code'] as String,
      name: json['name'] as String,
      parentCode: json['parent_sector_code'] as String? ?? json['parent_code'] as String?,
    );
  }
}

