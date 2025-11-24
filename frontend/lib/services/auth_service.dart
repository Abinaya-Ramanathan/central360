class AuthService {
  static bool _isAdmin = false;
  static bool _isMainAdmin = false;
  static String? _username;
  static String? _initialSector;

  static void setAuthData({
    required String username,
    required bool isAdmin,
    required bool isMainAdmin,
    String? initialSector,
  }) {
    _username = username;
    _isAdmin = isAdmin;
    _isMainAdmin = isMainAdmin;
    _initialSector = initialSector;
  }

  static String get username => _username ?? '';
  static bool get isAdmin => _isAdmin;
  static bool get isMainAdmin => _isMainAdmin;
  static String? get initialSector => _initialSector;

  static void clear() {
    _username = null;
    _isAdmin = false;
    _isMainAdmin = false;
    _initialSector = null;
  }
}

