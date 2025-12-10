import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../config/env_config.dart';
import 'format_utils.dart';

class PdfGenerator {
  // Helper function to load TTF font for Unicode support
  static Future<pw.Font> _loadUnicodeFont() async {
    try {
      print('PDF Generator: Attempting to load Roboto-Regular.ttf...');
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      print('PDF Generator: Successfully loaded Roboto-Regular.ttf (${fontData.lengthInBytes} bytes)');
      final font = pw.Font.ttf(fontData);
      print('PDF Generator: Created TTF font object: $font');
      return font;
    } catch (e) {
      print('ERROR: Could not load TTF font: $e');
      print('Falling back to Courier font (will have limited Unicode support)');
      return pw.Font.courier();
    }
  }

  static Future<pw.Font> _loadUnicodeFontBold() async {
    try {
      print('PDF Generator: Attempting to load Roboto-Bold.ttf...');
      final fontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      print('PDF Generator: Successfully loaded Roboto-Bold.ttf (${fontData.lengthInBytes} bytes)');
      final font = pw.Font.ttf(fontData);
      print('PDF Generator: Created TTF bold font object: $font');
      return font;
    } catch (e) {
      print('ERROR: Could not load TTF bold font: $e');
      print('Falling back to Courier font (will have limited Unicode support)');
      return pw.Font.courier();
    }
  }

  // Helper function to sanitize filename by replacing invalid characters
  static String _sanitizeFileName(String fileName) {
    // Replace forward slashes and backslashes with dashes (common in dates)
    return fileName.replaceAll(RegExp(r'[/\\]'), '-')
        .replaceAll(RegExp(r'[<>:"|?*]'), '_');
  }

  // Helper function to format date for PDF display
  static String _formatDateForPDF(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      if (dateValue is DateTime) {
        return FormatUtils.formatDateDisplay(dateValue);
      } else if (dateValue is String) {
        final dateStr = dateValue.split('T')[0].split(' ')[0];
        final parsed = FormatUtils.parseDate(dateStr);
        if (parsed != null) {
          return FormatUtils.formatDateDisplay(parsed);
        }
        return dateStr; // Return as-is if parsing fails
      }
      return dateValue.toString();
    } catch (e) {
      print('Error formatting date in PDF: $e, value: $dateValue');
      return dateValue?.toString() ?? '';
    }
  }

  // Helper function to format amount for PDF display
  static String _formatAmountForPDF(double? amount) {
    if (amount == null) return '';
    return 'Rs.${amount.toStringAsFixed(2)}';
  }

  // Helper function to safely parse amounts from any type (String, num, or null)
  static double _parseAmountValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static Future<void> generateAndDownloadCateringPDF({
    required String bookingId,
    String? deliveryLocation,
    String? morningFoodMenu,
    int morningFoodCount = 0,
    String? afternoonFoodMenu,
    int afternoonFoodCount = 0,
    String? eveningFoodMenu,
    int eveningFoodCount = 0,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [
            pw.Text(
              'Catering Details',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Booking ID: $bookingId', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ];

          // Add Delivery Location if it exists, right after Booking ID
          if (deliveryLocation != null && deliveryLocation.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(pw.Text('Delivery Location: $deliveryLocation', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
          }

          // Only add fields that have data, in the specified order
          bool hasMorningData = (morningFoodCount > 0) || (morningFoodMenu != null && morningFoodMenu.isNotEmpty);
          bool hasAfternoonData = (afternoonFoodCount > 0) || (afternoonFoodMenu != null && afternoonFoodMenu.isNotEmpty);
          bool hasEveningData = (eveningFoodCount > 0) || (eveningFoodMenu != null && eveningFoodMenu.isNotEmpty);

          if (hasMorningData) {
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(pw.Text('Morning Food Count: ${morningFoodCount > 0 ? morningFoodCount : 0}', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
            if (morningFoodMenu != null && morningFoodMenu.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 5));
              widgets.add(pw.Text('Morning Food Menu:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
              widgets.add(pw.Text(morningFoodMenu, style: const pw.TextStyle(fontSize: 12)));
            }
          }

          if (hasAfternoonData) {
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(pw.Text('Afternoon Food Count: ${afternoonFoodCount > 0 ? afternoonFoodCount : 0}', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
            if (afternoonFoodMenu != null && afternoonFoodMenu.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 5));
              widgets.add(pw.Text('Afternoon Food Menu:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
              widgets.add(pw.Text(afternoonFoodMenu, style: const pw.TextStyle(fontSize: 12)));
            }
          }

          if (hasEveningData) {
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(pw.Text('Evening Food Count: ${eveningFoodCount > 0 ? eveningFoodCount : 0}', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
            if (eveningFoodMenu != null && eveningFoodMenu.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 5));
              widgets.add(pw.Text('Evening Food Menu:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
              widgets.add(pw.Text(eveningFoodMenu, style: const pw.TextStyle(fontSize: 12)));
            }
          }

          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: widgets,
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static Future<void> generateAndDownloadExpensePDF({
    required List<Map<String, dynamic>> expenseData,
    required DateTime date,
    DateTime? dateTo,
    String? sectorName,
    bool showSectorColumn = false,
    List<Map<String, dynamic>>? sectors,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateStr = dateFormat.format(date);
    final dateToStr = dateTo != null ? dateFormat.format(dateTo) : dateStr;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Daily Expense Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                if (dateTo != null && dateTo != date)
                  pw.Text('Date Range: $dateStr to $dateToStr', style: const pw.TextStyle(fontSize: 14))
                else
                  pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 14)),
                if (sectorName != null)
                  pw.Text('Sector: $sectorName', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        if (showSectorColumn)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Sector', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Item Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Reason', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...expenseData.map((record) {
                      final amount = (record['amount'] is num)
                          ? (record['amount'] as num).toDouble()
                          : double.tryParse(record['amount']?.toString() ?? '0') ?? 0.0;
                      return pw.TableRow(
                        children: [
                          if (showSectorColumn)
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(sectors != null ? _getSectorNameForPDF(record, sectors) : record['sector_code']?.toString() ?? 'N/A'),
                            ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(record['item_details']?.toString() ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(amount.toStringAsFixed(2)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(record['reason_for_purchase']?.toString() ?? ''),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  static Future<void> generateAndSendExpensePDFEmail({
    required List<Map<String, dynamic>> expenseData,
    required DateTime date,
    DateTime? dateTo,
    String? sectorName,
    required String emailAddress,
    bool showSectorColumn = false,
    List<Map<String, dynamic>>? sectors,
  }) async {
    // Similar to credit email - generate PDF
    // Note: This requires backend integration for actual email sending
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateStr = dateFormat.format(date);
    final dateToStr = dateTo != null ? dateFormat.format(dateTo) : dateStr;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Daily Expense Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                if (dateTo != null && dateTo != date)
                  pw.Text('Date Range: $dateStr to $dateToStr', style: const pw.TextStyle(fontSize: 14))
                else
                  pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 14)),
                if (sectorName != null)
                  pw.Text('Sector: $sectorName', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        if (showSectorColumn)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Sector', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Item Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Reason', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...expenseData.map((record) {
                      final amount = (record['amount'] is num)
                          ? (record['amount'] as num).toDouble()
                          : double.tryParse(record['amount']?.toString() ?? '0') ?? 0.0;
                      return pw.TableRow(
                        children: [
                          if (showSectorColumn)
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(sectors != null ? _getSectorNameForPDF(record, sectors) : record['sector_code']?.toString() ?? 'N/A'),
                            ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(record['item_details']?.toString() ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(amount.toStringAsFixed(2)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(record['reason_for_purchase']?.toString() ?? ''),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // Convert PDF to base64 and send via API
    final pdfBytes = await pdf.save();
    final pdfBase64 = base64.encode(pdfBytes);
    
    try {
      // Send email via backend API
      await _sendEmailViaAPI(
        emailAddress: emailAddress,
        pdfBase64: pdfBase64,
        subject: 'Daily Expense Report',
        body: 'Please find attached the daily expense report.',
      );
    } catch (e) {
      // If API fails, download the PDF as fallback
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      rethrow;
    }
  }


  static String _getSectorNameForPDF(Map<String, dynamic> record, List<Map<String, dynamic>> sectors) {
    final sectorCode = record['sector_code']?.toString();
    if (sectorCode == null) return 'All Sectors';
    try {
      final sector = sectors.firstWhere(
        (s) => s['code']?.toString() == sectorCode,
      );
      return sector['name']?.toString() ?? sectorCode;
    } catch (e) {
      // If not found, return the code itself
      return sectorCode;
    }
  }

  static Future<void> generateAndDownloadCreditPDF({
    required List<Map<String, dynamic>> creditData,
    String? sectorName,
    bool showSectorColumn = false,
    List<Map<String, dynamic>>? sectors,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Credit Details Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (sectorName != null)
                  pw.Text('Sector: $sectorName', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        if (showSectorColumn)
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Sector', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Phone', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Credit Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Credit Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount Settled', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Pending Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...creditData.map((record) {
                      final creditAmount = (record['credit_amount'] is num)
                          ? (record['credit_amount'] as num).toDouble()
                          : double.tryParse(record['credit_amount']?.toString() ?? '0') ?? 0.0;
                      final amountSettled = (record['amount_settled'] is num)
                          ? (record['amount_settled'] as num).toDouble()
                          : double.tryParse(record['amount_settled']?.toString() ?? '0') ?? 0.0;
                      final pending = creditAmount - amountSettled;
                      final creditDateStr = _formatDateForPDF(record['credit_date']);
                      return pw.TableRow(
                        children: [
                          if (showSectorColumn)
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(sectors != null ? _getSectorNameForPDF(record, sectors) : record['sector_code']?.toString() ?? 'N/A'),
                            ),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['name']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['phone_number']?.toString() ?? 'N/A')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(creditAmount.toStringAsFixed(2))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(creditDateStr)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(amountSettled.toStringAsFixed(2))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(pending.toStringAsFixed(2))),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  static Future<void> generateAndSendCreditPDFEmail({
    required List<Map<String, dynamic>> creditData,
    String? sectorName,
    required String emailAddress,
    bool showSectorColumn = false,
    List<Map<String, dynamic>>? sectors,
  }) async {
    // Generate PDF first
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Credit Details Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (sectorName != null)
                  pw.Text('Sector: $sectorName', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        if (showSectorColumn)
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Sector', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Phone', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Credit Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Credit Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount Settled', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Pending Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...creditData.map((record) {
                      final creditAmount = (record['credit_amount'] is num)
                          ? (record['credit_amount'] as num).toDouble()
                          : double.tryParse(record['credit_amount']?.toString() ?? '0') ?? 0.0;
                      final amountSettled = (record['amount_settled'] is num)
                          ? (record['amount_settled'] as num).toDouble()
                          : double.tryParse(record['amount_settled']?.toString() ?? '0') ?? 0.0;
                      final pending = creditAmount - amountSettled;
                      final creditDateStr = _formatDateForPDF(record['credit_date']);
                      return pw.TableRow(
                        children: [
                          if (showSectorColumn)
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(sectors != null ? _getSectorNameForPDF(record, sectors) : record['sector_code']?.toString() ?? 'N/A'),
                            ),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['name']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['phone_number']?.toString() ?? 'N/A')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(creditAmount.toStringAsFixed(2))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(creditDateStr)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(amountSettled.toStringAsFixed(2))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(pending.toStringAsFixed(2))),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // Convert PDF to base64 and send via API
    final pdfBytes = await pdf.save();
    final pdfBase64 = base64.encode(pdfBytes);
    
    // Import API service dynamically to avoid circular dependency
    try {
      // Send email via backend API
      await _sendEmailViaAPI(
        emailAddress: emailAddress,
        pdfBase64: pdfBase64,
        subject: 'Credit Details Report',
        body: 'Please find attached the credit details report.',
      );
    } catch (e) {
      // If API fails, download the PDF as fallback
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      rethrow;
    }
  }

  static Future<void> _sendEmailViaAPI({
    required String emailAddress,
    required String pdfBase64,
    required String subject,
    required String body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${EnvConfig.apiEndpoint}/email/send-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emailAddress': emailAddress,
          'pdfBase64': pdfBase64,
          'subject': subject,
          'body': body,
        }),
      );
      
      if (response.statusCode != 200) {
        try {
          final errorBody = json.decode(response.body);
          final errorMessage = errorBody is Map ? (errorBody['message'] ?? errorBody['error'] ?? response.body) : response.body;
          final errorStr = errorMessage.toString();
          // Limit error message length to avoid display issues
          final limitedError = errorStr.length > 200 ? '${errorStr.substring(0, 200)}...' : errorStr;
          throw Exception(limitedError);
        } catch (e) {
          if (e is Exception) {
            rethrow;
          }
          throw Exception('Failed to send email: ${response.body}');
        }
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('Network error: Unable to connect to server. Please check if the backend is running.');
      } else if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to send email: $e');
      }
    }
  }

  // Helper function to get Downloads directory path
  static Future<String> _getDownloadsPath() async {
    try {
      if (Platform.isWindows) {
        // On Windows, try multiple methods to get Downloads folder
        // Method 1: Use USERPROFILE environment variable
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final downloadsPath = path.join(userProfile, 'Downloads');
          final downloadsDir = Directory(downloadsPath);
          if (await downloadsDir.exists()) {
            return downloadsPath;
          }
          // Try to create it
          try {
            await downloadsDir.create(recursive: true);
            return downloadsPath;
          } catch (e) {
            // Continue to next method
          }
        }
        
        // Method 2: Try HOME environment variable
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          final downloadsPath = path.join(home, 'Downloads');
          final downloadsDir = Directory(downloadsPath);
          if (await downloadsDir.exists()) {
            return downloadsPath;
          }
        }
        
        // Method 3: Use path_provider to get Documents and navigate
        try {
          final documentsDir = await getApplicationDocumentsDirectory();
          final userPath = path.dirname(path.dirname(documentsDir.path));
          final downloadsPath = path.join(userPath, 'Downloads');
          final downloadsDir = Directory(downloadsPath);
          if (await downloadsDir.exists()) {
            return downloadsPath;
          }
          // Try to create it
          await downloadsDir.create(recursive: true);
          return downloadsPath;
        } catch (e) {
          // Fallback to Documents
          final documentsDir = await getApplicationDocumentsDirectory();
          return documentsDir.path;
        }
      } else if (Platform.isAndroid) {
        // On Android, try multiple paths
        // Method 1: Try standard Downloads path
        const standardPath = '/storage/emulated/0/Download';
        final standardDir = Directory(standardPath);
        if (await standardDir.exists()) {
          return standardPath;
        }
        
        // Method 2: Try to get from external storage directory
        try {
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            // Get parent directory and navigate to Download
            final parentPath = path.dirname(directory.path);
            final downloadsPath = path.join(parentPath, 'Download');
            final downloadsDir = Directory(downloadsPath);
            if (await downloadsDir.exists()) {
              return downloadsPath;
            }
            // Try to create it
            try {
              await downloadsDir.create(recursive: true);
              return downloadsPath;
            } catch (e) {
              // Continue to next method
            }
          }
        } catch (e) {
          // Continue to fallback
        }
        
        // Method 3: Try to create standard path
        try {
          await standardDir.create(recursive: true);
          return standardPath;
        } catch (e) {
          // Fallback to app's external storage
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            return directory.path;
          }
        }
        
        // Final fallback: use app documents directory
        final documentsDir = await getApplicationDocumentsDirectory();
        return documentsDir.path;
      } else {
        // For other platforms, use documents directory
        final directory = await getApplicationDocumentsDirectory();
        return directory.path;
      }
    } catch (e) {
      // Ultimate fallback: use application documents directory
      try {
        final directory = await getApplicationDocumentsDirectory();
        return directory.path;
      } catch (fallbackError) {
        // Last resort: use current directory
        return Directory.current.path;
      }
    }
  }

  // Helper function to save PDF to Downloads folder
  static Future<String> _savePdfToDownloads(pw.Document pdf, String fileName) async {
    String? savedPath;
    Exception? lastError;
    
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        try {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            // Try with manageExternalStorage for Android 11+
            final manageStatus = await Permission.manageExternalStorage.request();
            if (!manageStatus.isGranted) {
              // For Android 10+, we might not need explicit permission
              // Continue and try to save anyway
            }
          }
        } catch (e) {
          // Permission request failed, but continue anyway
          // Some Android versions handle this differently
        }
      }

      // Try to save to Downloads folder
      try {
        final downloadsPath = await _getDownloadsPath();
        
        // Normalize the path to handle any issues
        final normalizedPath = path.normalize(downloadsPath);
        
        // Ensure the Downloads directory exists
        final downloadsDir = Directory(normalizedPath);
        if (!await downloadsDir.exists()) {
          try {
            await downloadsDir.create(recursive: true);
          } catch (createError) {
            throw Exception('Could not create Downloads directory at: $normalizedPath. Error: $createError');
          }
        }
        
        // Verify directory exists and is accessible
        if (!await downloadsDir.exists()) {
          throw Exception('Downloads directory does not exist and could not be created: $normalizedPath');
        }
        
        // Sanitize filename to remove invalid characters (especially forward slashes from dates)
        final sanitizedFileName = _sanitizeFileName(fileName);
        final filePath = path.join(normalizedPath, sanitizedFileName);
        final normalizedFilePath = path.normalize(filePath);
        final file = File(normalizedFilePath);
        
        // Write PDF bytes to file
        try {
          final pdfBytes = await pdf.save();
          await file.writeAsBytes(pdfBytes);
        } catch (writeError) {
          throw Exception('Failed to write PDF file at: $normalizedFilePath. Error: $writeError');
        }
        
        // Verify file was written
        if (await file.exists()) {
          savedPath = normalizedFilePath;
          return normalizedFilePath;
        } else {
          throw Exception('File was not created successfully at: $normalizedFilePath');
        }
      } catch (downloadsError) {
        lastError = downloadsError is Exception ? downloadsError : Exception(downloadsError.toString());
        // Continue to fallback
      }
      
      // Fallback: Try saving to Documents directory
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final filePath = path.join(documentsDir.path, fileName);
        final normalizedFilePath = path.normalize(filePath);
        final file = File(normalizedFilePath);
        final pdfBytes = await pdf.save();
        await file.writeAsBytes(pdfBytes);
        
        if (await file.exists()) {
          savedPath = normalizedFilePath;
          return normalizedFilePath;
        }
      } catch (documentsError) {
        lastError = documentsError is Exception ? documentsError : Exception(documentsError.toString());
      }
      
      // If all methods failed, throw an error with helpful message
      // At this point, lastError should always be set (from either downloadsError or documentsError)
      final errorMessage = lastError.toString().replaceFirst('Exception: ', '');
      throw Exception('Failed to save PDF to Downloads folder. Error: $errorMessage${savedPath != null ? ' File saved to: $savedPath' : ''}');
      
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      throw Exception('Failed to save PDF: $errorMessage${savedPath != null ? ' However, file was saved to: $savedPath' : ''}');
    }
  }

  // Generate Sales Details PDF
  static Future<String> generateSalesDetailsPDF({
    required List<Map<String, dynamic>> salesData,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Sales Details Statement',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'From: ${dateFormat.format(fromDate)} To: ${dateFormat.format(toDate)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Sector', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Quantity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount Received', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Credit Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...salesData.map((record) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(FormatUtils.formatDateDisplay(DateTime.parse(record['sale_date'])))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['sector_code']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['name']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['product_name']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['quantity']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((double.tryParse(record['amount_received']?.toString() ?? '0') ?? 0).toStringAsFixed(2))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((double.tryParse(record['credit_amount']?.toString() ?? '0') ?? 0).toStringAsFixed(2))),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final fileName = _sanitizeFileName('Sales_Details_${dateFormat.format(fromDate)}_to_${dateFormat.format(toDate)}.pdf');
    final filePath = await _savePdfToDownloads(pdf, fileName);
    return filePath;
  }

  // Generate Customer Credit Details PDF
  static Future<String> generateCustomerCreditDetailsPDF({
    required List<Map<String, dynamic>> creditData,
    int? totalRecords,
    String? fileName,
  }) async {
    print('PDF Generator: Received ${creditData.length} rows');
    print('PDF Generator: creditData.isEmpty = ${creditData.isEmpty}');
    if (creditData.isNotEmpty) {
      print('PDF Generator: First row type: ${creditData.first['type']}');
      print('PDF Generator: Sample row keys: ${creditData.first.keys.toList()}');
      print('PDF Generator: Sample row values: ${creditData.first}');
    }
    
    final pdf = pw.Document();

    // Load Unicode-capable fonts BEFORE adding page
    final unicodeFont = await _loadUnicodeFont();
    final unicodeFontBold = await _loadUnicodeFontBold();
    print('PDF Generator: Loaded unicodeFont=${unicodeFont.runtimeType}, unicodeFontBold=${unicodeFontBold.runtimeType}');
    
    final headerStyle = pw.TextStyle(font: unicodeFontBold, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black);
    final cellStyle = pw.TextStyle(font: unicodeFont, fontSize: 10, color: PdfColors.black);
    print('PDF Generator: Created styles with fonts');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          print('PDF Generator: Building PDF page, creditData.length = ${creditData.length}');
          
          // Build table rows list inside build callback
          final List<pw.TableRow> tableRows = [];
          
          // Add header row (use Unicode-capable font)
          tableRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Date', style: headerStyle)),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Name', style: headerStyle)),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Product', style: headerStyle)),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Credit Amount', style: headerStyle)),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Balance Paid', style: headerStyle)),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Balance Paid Date', style: headerStyle)),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Overall Balance', style: headerStyle)),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Details', style: headerStyle)),
              ],
            ),
          );
          
          // Build data rows
          print('PDF Generator: Starting to build ${creditData.length} table rows');
          for (var record in creditData) {
            try {
              print('PDF Generator: Processing row type: ${record['type']}');
              final rowType = record['type'] as String? ?? 'main';
              final creditAmount = record['credit_amount'] != null 
                  ? (double.tryParse(record['credit_amount'].toString()) ?? 0.0)
                  : null;
              final balancePaid = record['balance_paid'] != null
                  ? (double.tryParse(record['balance_paid'].toString()) ?? 0.0)
                  : null;
              final overallBalance = record['overall_balance'] != null
                  ? (double.tryParse(record['overall_balance'].toString()) ?? 0.0)
                  : 0.0;
            
              // Handle different row types
              if (rowType == 'total') {
                // Total row
                tableRows.add(
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(
                          'TOTAL',
                          style: pw.TextStyle(font: unicodeFontBold, fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.black),
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(
                          _formatAmountForPDF(overallBalance),
                          style: pw.TextStyle(font: unicodeFontBold, fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.black),
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                    ],
                  ),
                );
              } else if (rowType == 'payment') {
                // Payment row (sub-row)
                final balancePaidDateStr = _formatDateForPDF(record['balance_paid_date']);
                
                tableRows.add(
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('', style: cellStyle)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(_formatAmountForPDF(balancePaid), style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(balancePaidDateStr, style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(_formatAmountForPDF(overallBalance), style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(record['details']?.toString() ?? '', style: cellStyle),
                      ),
                    ],
                  ),
                );
              } else {
                // Main row
                final saleDateStr = _formatDateForPDF(record['sale_date']);
                final balancePaidDateStr = _formatDateForPDF(record['balance_paid_date']);
                
                print('PDF DEBUG - Main row: date=$saleDateStr, name=${record['name']}, amount=$creditAmount');
                
                final nameText = record['name']?.toString() ?? '';
                final productText = record['product_name']?.toString() ?? '';
                final amountText = _formatAmountForPDF(creditAmount);
                print('PDF DEBUG - Cell texts: nameText="$nameText", productText="$productText", amountText="$amountText"');
                
                tableRows.add(
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(saleDateStr, style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(record['name']?.toString() ?? '', style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(record['product_name']?.toString() ?? '', style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(_formatAmountForPDF(creditAmount), style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(_formatAmountForPDF(balancePaid), style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(balancePaidDateStr, style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(_formatAmountForPDF(overallBalance), style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(record['details']?.toString() ?? '', style: cellStyle),
                      ),
                    ],
                  ),
                );
              }
            } catch (e) {
              print('Error generating PDF row: $e');
              print('Error record: $record');
              // Continue with next row
            }
          }
          
          print('PDF Generator: Built ${tableRows.length} table rows (1 header + ${tableRows.length - 1} data rows)');
          
          if (tableRows.isEmpty) {
            print('PDF Generator: WARNING - tableRows is empty!');
          } else {
            print('PDF Generator: First table row has ${tableRows.first.children.length} cells');
            if (tableRows.length > 1) {
              print('PDF Generator: Second table row has ${tableRows[1].children.length} cells');
              // Debug: Print first data row content
              if (tableRows[1].children.isNotEmpty) {
                print('PDF Generator: First data cell text: ${tableRows[1].children[0]}');
              }
            }
          }
          
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Customer Credit Details Statement',
                  style: pw.TextStyle(font: unicodeFontBold, fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                tableRows.isEmpty
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.all(20),
                        child: pw.Text(
                          'No credit data available for the selected filters',
                          style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
                        ),
                      )
                    : pw.SizedBox(
                        width: double.infinity,
                        child: pw.Table(
                          border: pw.TableBorder.all(),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(1.2), // Date
                            1: const pw.FlexColumnWidth(1.5), // Name
                            2: const pw.FlexColumnWidth(1.5), // Product
                            3: const pw.FlexColumnWidth(1.2), // Credit Amount
                            4: const pw.FlexColumnWidth(1.2), // Balance Paid
                            5: const pw.FlexColumnWidth(1.2), // Balance Paid Date
                            6: const pw.FlexColumnWidth(1.2), // Overall Balance
                            7: const pw.FlexColumnWidth(2.0), // Details
                          },
                          children: tableRows,
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
    
    const defaultFileName = 'Customer_Credit_Details.pdf';
    final finalFileName = fileName != null 
        ? _sanitizeFileName('$fileName.pdf')
        : _sanitizeFileName(defaultFileName);
    final filePath = await _savePdfToDownloads(pdf, finalFileName);
    return filePath;
  }

  // Generate Company Purchase PDF
  static Future<String> generateCompanyPurchasePDF({
    required List<Map<String, dynamic>> purchaseData,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Company Purchase Details Statement',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'From: ${dateFormat.format(fromDate)} To: ${dateFormat.format(toDate)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Sector', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Shop Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Purchase Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Credit Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...purchaseData.map((record) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(FormatUtils.formatDateDisplay(DateTime.parse(record['purchase_date'])))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['sector_code']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['name']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['purchase_details']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((double.tryParse(record['amount']?.toString() ?? '0') ?? 0).toStringAsFixed(2))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((double.tryParse(record['credit_amount']?.toString() ?? '0') ?? 0).toStringAsFixed(2))),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final fileName = _sanitizeFileName('Company_Purchase_Details_${dateFormat.format(fromDate)}_to_${dateFormat.format(toDate)}.pdf');
    final filePath = await _savePdfToDownloads(pdf, fileName);
    return filePath;
  }

  // Generate Advance Details PDF
  static Future<String> generateAdvanceDetailsPDF({
    required List<Map<String, dynamic>> advanceData,
    required String fileName,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          // Build table rows list
          final List<pw.TableRow> tableRows = [];
          
          // Check if bulk advance column is needed
          final showBulkColumn = advanceData.any((d) => ((d['bulk_advance'] as num?)?.toDouble() ?? 0.0) > 0.01);
          
          // Add header row
          final headerChildren = <pw.Widget>[
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Sector', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Employee Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Outstanding Advance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ];
          
          if (showBulkColumn) {
            headerChildren.add(
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Bulk Advance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            );
          }
          
          tableRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: headerChildren,
            ),
          );
          
          // Calculate totals
          double totalOutstandingAdvance = 0.0;
          double totalBulkAdvance = 0.0;
          
          // Build data rows
          for (var record in advanceData) {
            final outstandingAdvance = (record['outstanding_advance'] as num?)?.toDouble() ?? 0.0;
            final bulkAdvance = (record['bulk_advance'] as num?)?.toDouble() ?? 0.0;
            
            totalOutstandingAdvance += outstandingAdvance;
            totalBulkAdvance += bulkAdvance;
            
            final rowChildren = <pw.Widget>[
              pw.Padding(
                padding: const pw.EdgeInsets.all(8), 
                child: pw.Text(record['sector_code']?.toString() ?? 'N/A'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8), 
                child: pw.Text(record['employee_name']?.toString() ?? 'N/A'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8), 
                child: pw.Text(
                  'Rs.${outstandingAdvance.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ];
            
            if (showBulkColumn) {
              rowChildren.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8), 
                  child: pw.Text(
                    bulkAdvance > 0.01 ? 'Rs.${bulkAdvance.toStringAsFixed(2)}' : 'Rs.0.00',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              );
            }
            
            tableRows.add(
              pw.TableRow(
                children: rowChildren,
              ),
            );
          }
          
          // Add total row
          final totalRowChildren = <pw.Widget>[
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8), 
              child: pw.Text(
                'TOTAL',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8), 
              child: pw.Text(
                'Rs.${totalOutstandingAdvance.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
              ),
            ),
          ];
          
          if (showBulkColumn) {
            totalRowChildren.add(
              pw.Padding(
                padding: const pw.EdgeInsets.all(8), 
                child: pw.Text(
                  'Rs.${totalBulkAdvance.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
              ),
            );
          }
          
          tableRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: totalRowChildren,
            ),
          );
          
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Advance Details Statement',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                advanceData.isEmpty
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.all(20),
                        child: pw.Text(
                          'No data available',
                          style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
                        ),
                      )
                    : pw.Table(
                        border: pw.TableBorder.all(),
                        children: tableRows,
                      ),
              ],
            ),
          );
        },
      ),
    );
    
    final finalFileName = _sanitizeFileName('$fileName.pdf');
    final filePath = await _savePdfToDownloads(pdf, finalFileName);
    return filePath;
  }

  // Generate Company Purchase Credit Details PDF
  static Future<String> generateCompanyPurchaseCreditDetailsPDF({
    required List<Map<String, dynamic>> creditData,
    required String fileName,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          // Build table rows list
          final List<pw.TableRow> tableRows = [];
          
          // Add header row
          tableRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Shop Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Purchase Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Credit Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Balance Paid', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Balance Paid Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Overall Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ],
            ),
          );
          
          // Build data rows
          for (var record in creditData) {
            try {
              final rowType = record['type'] as String? ?? 'main';
              final creditAmount = record['credit'] != null 
                  ? (double.tryParse(record['credit'].toString()) ?? 0.0)
                  : null;
              final balancePaid = record['balance_paid'] != null
                  ? (double.tryParse(record['balance_paid'].toString()) ?? 0.0)
                  : null;
              final overallBalance = record['overall_balance'] != null
                  ? (double.tryParse(record['overall_balance'].toString()) ?? 0.0)
                  : 0.0;
            
              // Handle different row types
              if (rowType == 'total') {
                // Total row
                tableRows.add(
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(
                          'TOTAL',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(
                          'Rs.${overallBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                    ],
                  ),
                );
              } else if (rowType == 'payment') {
                // Payment row (sub-row)
                tableRows.add(
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('')),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(balancePaid != null ? 'Rs.${balancePaid.toStringAsFixed(2)}' : ''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(
                          record['balance_paid_date'] != null 
                              ? (record['balance_paid_date'] is DateTime
                                  ? FormatUtils.formatDateDisplay(record['balance_paid_date'] as DateTime)
                                  : FormatUtils.formatDateDisplay(DateTime.parse(record['balance_paid_date'].toString())))
                              : '',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text('Rs.${overallBalance.toStringAsFixed(2)}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(record['details']?.toString() ?? ''),
                      ),
                    ],
                  ),
                );
              } else {
                // Main row
                tableRows.add(
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(
                          record['purchase_date'] != null 
                              ? FormatUtils.formatDateDisplay(DateTime.parse(record['purchase_date'].toString()))
                              : '',
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['item_name']?.toString() ?? '')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['shop_name']?.toString() ?? '')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['purchase_details']?.toString() ?? '')),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(creditAmount != null ? 'Rs.${creditAmount.toStringAsFixed(2)}' : ''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(balancePaid != null ? 'Rs.${balancePaid.toStringAsFixed(2)}' : ''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(
                          record['balance_paid_date'] != null 
                              ? (record['balance_paid_date'] is DateTime
                                  ? FormatUtils.formatDateDisplay(record['balance_paid_date'] as DateTime)
                                  : FormatUtils.formatDateDisplay(DateTime.parse(record['balance_paid_date'].toString())))
                              : '',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text('Rs.${overallBalance.toStringAsFixed(2)}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(record['details']?.toString() ?? ''),
                      ),
                    ],
                  ),
                );
              }
            } catch (e) {
              print('Error generating PDF row: $e');
              print('Error record: $record');
              // Continue with next row
            }
          }
          
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Company Purchase Credit Details Statement',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                creditData.isEmpty
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.all(20),
                        child: pw.Text(
                          'No data available',
                          style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
                        ),
                      )
                    : pw.Table(
                        border: pw.TableBorder.all(),
                        children: tableRows,
                      ),
              ],
            ),
          );
        },
      ),
    );
    
    final finalFileName = _sanitizeFileName('$fileName.pdf');
    final filePath = await _savePdfToDownloads(pdf, finalFileName);
    return filePath;
  }

  // Generate Credit Details PDF
  static Future<String> generateCreditDetailsPDF({
    required List<Map<String, dynamic>> creditData,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final pdf = pw.Document();
    // Load Unicode-capable fonts for PDF text rendering
    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();
    final headerStyle = pw.TextStyle(font: ttfBold, fontSize: 12);
    final cellStyle = pw.TextStyle(font: ttf, fontSize: 10);
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Credit Details Statement',
                  style: pw.TextStyle(font: ttfBold, fontSize: 20),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'From: ${dateFormat.format(fromDate)} To: ${dateFormat.format(toDate)}',
                  style: pw.TextStyle(font: ttf, fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Date', style: headerStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Shop Name', style: headerStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Purchase Details', style: headerStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Credit Amount', style: headerStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount Settled', style: headerStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Pending Amount', style: headerStyle)),
                      ],
                    ),
                    ...creditData.map((record) {
                      final creditAmount = double.tryParse(record['credit_amount']?.toString() ?? '0') ?? 0.0;
                      final amountSettled = double.tryParse(record['amount_settled']?.toString() ?? '0') ?? 0.0;
                      final pendingAmount = creditAmount - amountSettled;
                      
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['credit_date'] != null ? FormatUtils.formatDateDisplay(DateTime.parse(record['credit_date'])) : '', style: cellStyle)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['name']?.toString() ?? '', style: cellStyle)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['purchase_details']?.toString() ?? '', style: cellStyle)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(creditAmount.toStringAsFixed(2), style: cellStyle)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(amountSettled.toStringAsFixed(2), style: cellStyle)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(pendingAmount.toStringAsFixed(2), style: cellStyle)),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final fileName = _sanitizeFileName('Credit_Details_${dateFormat.format(fromDate)}_to_${dateFormat.format(toDate)}.pdf');
    final filePath = await _savePdfToDownloads(pdf, fileName);
    return filePath;
  }

  // Generate Overall Income/Expense PDF
  static Future<void> generateOverallIncomeExpenseReport({
    required List<Map<String, dynamic>> data,
    required List<DateTime> selectedDates,
    required List<String> selectedMonths,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy');
    final monthFormat = DateFormat('MMM yyyy');

    // Load Unicode-capable fonts
    final unicodeFont = await _loadUnicodeFont();
    final unicodeFontBold = await _loadUnicodeFontBold();
    print('PDF Generator (Overall Income/Expense): Loaded fonts - unicodeFont=${unicodeFont.runtimeType}, unicodeFontBold=${unicodeFontBold.runtimeType}');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
                pw.Text(
                  'Overall Income and Expense Report',
                  style: pw.TextStyle(
                    font: unicodeFontBold,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              pw.SizedBox(height: 20),
              // Selected Dates
              if (selectedDates.isNotEmpty) ...[
                pw.Text(
                  'Selected Dates:',
                  style: pw.TextStyle(font: unicodeFontBold, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  selectedDates.map((d) => dateFormat.format(d)).join(', '),
                  style: pw.TextStyle(font: unicodeFont, fontSize: 12, color: PdfColors.black),
                ),
                pw.SizedBox(height: 10),
              ],
              // Selected Months
              if (selectedMonths.isNotEmpty) ...[
                pw.Text(
                  'Selected Months:',
                  style: pw.TextStyle(font: unicodeFontBold, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  selectedMonths.join(', '),
                  style: pw.TextStyle(font: unicodeFont, fontSize: 12, color: PdfColors.black),
                ),
                pw.SizedBox(height: 20),
              ],
              // Table
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Sector Name',
                          style: pw.TextStyle(font: unicodeFontBold, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total Income',
                          style: pw.TextStyle(font: unicodeFontBold, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total Expense',
                          style: pw.TextStyle(font: unicodeFontBold, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Data Rows
                  ...data.map((item) {
                    final totalIncome = _parseAmountValue(item['total_income']);
                    final totalExpense = _parseAmountValue(item['total_expense']);
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(item['sector_name']?.toString() ?? '', style: pw.TextStyle(font: unicodeFont, color: PdfColors.black)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Rs${totalIncome.toStringAsFixed(2)}',
                            style: pw.TextStyle(font: unicodeFont, color: PdfColors.black),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Rs${totalExpense.toStringAsFixed(2)}',
                            style: pw.TextStyle(font: unicodeFont, color: PdfColors.black),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                  // Grand Total Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Grand Total',
                          style: pw.TextStyle(font: unicodeFontBold, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs${data.fold<double>(0, (sum, item) => sum + _parseAmountValue(item['total_income'])).toStringAsFixed(2)}',
                          style: pw.TextStyle(font: unicodeFontBold, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs${data.fold<double>(0, (sum, item) => sum + _parseAmountValue(item['total_expense'])).toStringAsFixed(2)}',
                          style: pw.TextStyle(font: unicodeFontBold, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final dateStr = selectedDates.isNotEmpty
        ? '${dateFormat.format(selectedDates.first)}_to_${dateFormat.format(selectedDates.last)}'
        : '';
    final monthStr = selectedMonths.isNotEmpty ? selectedMonths.join('_') : '';
    final fileName = _sanitizeFileName(
      'Overall_Income_Expense_${dateStr}_${monthStr}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await _savePdfToDownloads(pdf, fileName);
  }
}

