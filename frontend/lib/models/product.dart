class Product {
  final int id;
  final String productName;
  final String sectorCode;

  const Product({
    required this.id,
    required this.productName,
    required this.sectorCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'sector_code': sectorCode,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      productName: json['product_name'] as String,
      sectorCode: json['sector_code'] as String,
    );
  }
}

