class Sector {
  final String code;
  final String name;

  const Sector({required this.code, required this.name});

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
    };
  }

  factory Sector.fromJson(Map<String, dynamic> json) {
    return Sector(
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}

