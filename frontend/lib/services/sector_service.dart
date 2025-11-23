import '../models/sector.dart';

class SectorService {
  static final SectorService _instance = SectorService._internal();
  factory SectorService() => _instance;
  SectorService._internal();

  List<Sector> _sectors = [];

  List<Sector> get sectors => List.unmodifiable(_sectors);

  set sectors(List<Sector> value) {
    _sectors = value;
  }

  void addSector(Sector sector) {
    if (!_sectors.any((s) => s.code == sector.code)) {
      _sectors.add(sector);
    }
  }

  Sector? getByCode(String code) {
    try {
      return _sectors.firstWhere((s) => s.code == code);
    } catch (e) {
      return null;
    }
  }

  String getDisplayName(String code) {
    final sector = getByCode(code);
    return sector?.name ?? code;
  }

  bool sectorExists(String code) {
    return _sectors.any((s) => s.code == code);
  }

  void clearSectors() {
    _sectors.clear();
  }
}

