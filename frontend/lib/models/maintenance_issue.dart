class MaintenanceIssue {
  final int? id;
  final String? issueDescription;
  final DateTime? dateCreated;
  final String? imageUrl;
  final String status;
  final DateTime? dateResolved;
  final String sectorCode;
  final String? sectorName;

  MaintenanceIssue({
    this.id,
    this.issueDescription,
    this.dateCreated,
    this.imageUrl,
    this.status = 'Not resolved',
    this.dateResolved,
    required this.sectorCode,
    this.sectorName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_description': issueDescription,
      'date_created': dateCreated?.toIso8601String().split('T')[0],
      'image_url': imageUrl,
      'status': status,
      'date_resolved': dateResolved?.toIso8601String().split('T')[0],
      'sector_code': sectorCode,
    };
  }

  factory MaintenanceIssue.fromJson(Map<String, dynamic> json) {
    return MaintenanceIssue(
      id: json['id'] as int?,
      issueDescription: json['issue_description'] as String?,
      dateCreated: json['date_created'] != null
          ? DateTime.parse(json['date_created'] as String)
          : null,
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? 'Not resolved',
      dateResolved: json['date_resolved'] != null
          ? DateTime.parse(json['date_resolved'] as String)
          : null,
      sectorCode: json['sector_code'] as String,
      sectorName: json['sector_name'] as String?,
    );
  }

  MaintenanceIssue copyWith({
    int? id,
    String? issueDescription,
    DateTime? dateCreated,
    String? imageUrl,
    String? status,
    DateTime? dateResolved,
    String? sectorCode,
    String? sectorName,
  }) {
    return MaintenanceIssue(
      id: id ?? this.id,
      issueDescription: issueDescription ?? this.issueDescription,
      dateCreated: dateCreated ?? this.dateCreated,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      dateResolved: dateResolved ?? this.dateResolved,
      sectorCode: sectorCode ?? this.sectorCode,
      sectorName: sectorName ?? this.sectorName,
    );
  }
}

