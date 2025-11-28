/// Application-wide constants
library;

class AppConstants {
  // Date formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateDisplayFormat = 'dd/MM/yyyy';
  
  // Currency
  static const String currencySymbol = '₹';
  static const int currencyDecimals = 2;
  
  // Default values
  static const double defaultDecimalValue = 0.0;
  static const String defaultDateValue = 'N/A';
  
  // UI Constants
  static const double defaultButtonHeight = 50.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultIconSize = 20.0;
  
  // Admin credentials (for reference - actual check is in backend)
  static const String mainAdminPassword = 'abinaya';
  
  // Error messages
  static const String errorLoadingData = 'Error loading data';
  static const String errorSavingData = 'Error saving data';
  static const String errorDeletingData = 'Error deleting data';
  static const String successSaved = 'Saved successfully';
  static const String successDeleted = 'Deleted successfully';
}

