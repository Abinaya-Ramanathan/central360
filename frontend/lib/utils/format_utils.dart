/// Utility functions for formatting and parsing common data types
library;

class FormatUtils {
  /// Parse a dynamic value to a double, returning 0.0 if parsing fails
  static double parseDecimal(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  /// Format a date value to YYYY-MM-DD string, handling timezone issues
  static String formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      DateTime? dateTime;
      
      if (dateValue is String) {
        // First, try to extract just the date part (YYYY-MM-DD) before any T or space
        final dateStr = dateValue.split('T')[0].split(' ')[0];
        
        // Try parsing as a simple date string first (YYYY-MM-DD)
        dateTime = DateTime.tryParse(dateStr);
        
        // If that fails, try parsing the full ISO string
        if (dateTime == null) {
          final parsed = DateTime.tryParse(dateValue);
          if (parsed != null) {
            // Use date components from the string itself to avoid timezone issues
            final parts = dateStr.split('-');
            if (parts.length == 3) {
              final year = int.tryParse(parts[0]);
              final month = int.tryParse(parts[1]);
              final day = int.tryParse(parts[2]);
              if (year != null && month != null && day != null) {
                dateTime = DateTime(year, month, day);
              }
            }
            
            // If still null, use parsed date but extract date components
            dateTime ??= DateTime(parsed.year, parsed.month, parsed.day);
          }
        }
      } else if (dateValue is DateTime) {
        // Use date components directly to avoid timezone issues
        dateTime = DateTime(dateValue.year, dateValue.month, dateValue.day);
      }
      
      if (dateTime != null) {
        // Format as YYYY-MM-DD
        final year = dateTime.year.toString().padLeft(4, '0');
        final month = dateTime.month.toString().padLeft(2, '0');
        final day = dateTime.day.toString().padLeft(2, '0');
        return '$year-$month-$day';
      }
      
      // Fallback: try to extract date from string
      final dateStr = dateValue.toString().split('T')[0].split(' ')[0];
      if (dateStr.length >= 10) {
        return dateStr.substring(0, 10); // Return YYYY-MM-DD part
      }
      return dateStr;
    } catch (e) {
      return 'N/A';
    }
  }

  /// Parse a date string to DateTime, handling various formats
  static DateTime? parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is DateTime) {
        return DateTime(dateValue.year, dateValue.month, dateValue.day);
      }
      if (dateValue is String) {
        final dateStr = dateValue.trim();
        
        // Try parsing DD/MM/YYYY format first
        final ddmmyyyyParts = dateStr.split('/');
        if (ddmmyyyyParts.length == 3) {
          final day = int.tryParse(ddmmyyyyParts[0]);
          final month = int.tryParse(ddmmyyyyParts[1]);
          final year = int.tryParse(ddmmyyyyParts[2]);
          if (day != null && month != null && year != null) {
            if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 1900 && year <= 2100) {
              return DateTime(year, month, day);
            }
          }
        }
        
        // Try parsing YYYY-MM-DD format
        final dateStr2 = dateStr.split('T')[0].split(' ')[0];
        final dateParts = dateStr2.split('-');
        if (dateParts.length == 3) {
          final year = int.tryParse(dateParts[0]);
          final month = int.tryParse(dateParts[1]);
          final day = int.tryParse(dateParts[2]);
          if (year != null && month != null && day != null) {
            return DateTime(year, month, day);
          }
        }
        return DateTime.tryParse(dateStr2);
      }
    } catch (e) {
      // Ignore parse errors
    }
    return null;
  }

  /// Format currency amount with ₹ symbol
  static String formatCurrency(double amount, {int decimals = 2}) {
    return '₹${amount.toStringAsFixed(decimals)}';
  }

  /// Format date to DD/MM/YYYY for display
  static String formatDateDisplay(dynamic dateValue) {
    final dateStr = formatDate(dateValue);
    if (dateStr == 'N/A') return dateStr;
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (e) {
      // Ignore errors
    }
    return dateStr;
  }
}

