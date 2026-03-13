class AuthService {
  static bool _isAdmin = false;
  static bool _isMainAdmin = false;
  static String? _username;
  /// Sector codes the user can access (keyword login: cafe, crusher, etc.). Null for admin.
  static List<String>? _initialSectorCodes;

  static void setAuthData({
    required String username,
    required bool isAdmin,
    required bool isMainAdmin,
    List<String>? initialSectorCodes,
  }) {
    _username = username;
    _isAdmin = isAdmin;
    _isMainAdmin = isMainAdmin;
    _initialSectorCodes = initialSectorCodes;
  }

  static String get username => _username ?? '';
  static bool get isAdmin => _isAdmin;
  static bool get isMainAdmin => _isMainAdmin;
  static List<String>? get initialSectorCodes => _initialSectorCodes;

  static void clear() {
    _username = null;
    _isAdmin = false;
    _isMainAdmin = false;
    _initialSectorCodes = null;
  }
}

