import 'dart:async';
import '../services/api_service.dart';
import '../models/vehicle_license.dart';
import '../models/driver_license.dart';
import '../models/engine_oil_service.dart';
import '../models/mahal_booking.dart';
import 'notification_service.dart';

class ExpiryNotificationService {
  static final ExpiryNotificationService _instance = ExpiryNotificationService._internal();
  factory ExpiryNotificationService() => _instance;
  ExpiryNotificationService._internal();

  final NotificationService _notificationService = NotificationService();
  Timer? _checkTimer;

  /// Initialize and start checking for expiry dates
  Future<void> initialize() async {
    // Initialize notification service
    await _notificationService.initialize();

    // Request notification permission
    await _notificationService.requestNotificationPermission();

    // Start periodic checks (check once per day)
    _startPeriodicCheck();
  }

  /// Start periodic check for expiry dates
  void _startPeriodicCheck() {
    // Cancel existing timer if any
    _checkTimer?.cancel();

    // Check immediately after a short delay (to allow app to fully initialize)
    Future.delayed(const Duration(seconds: 5), () {
      checkExpiryDatesNow();
    });

    // Then check once per day (24 hours)
    _checkTimer = Timer.periodic(const Duration(hours: 24), (_) {
      checkExpiryDatesNow();
    });
  }

  /// Stop periodic checks
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Check all dates for expiry (2 days before) - Can be called manually
  Future<void> checkExpiryDatesNow() async {
    try {
      // Get all vehicle licenses (checks Permit, Insurance, Fitness, Pollution, Tax dates)
      final vehicleLicenses = await ApiService.getVehicleLicenses();
      await _notificationService.checkVehicleExpiries(vehicleLicenses);

      // Get all driver licenses (checks Expiry Date)
      final driverLicenses = await ApiService.getDriverLicenses();
      await _notificationService.checkDriverExpiries(driverLicenses);

      // Get all engine oil services (checks Next Service Date)
      final engineOilServices = await ApiService.getEngineOilServices();
      await _notificationService.checkEngineOilServiceExpiries(engineOilServices);

      // Get all mahal bookings (checks Event Date)
      final mahalBookings = await ApiService.getMahalBookings();
      await _notificationService.checkMahalBookingEventDates(mahalBookings);
    } catch (e) {
      print('Error checking expiry dates: $e');
      // Don't throw - just log the error
    }
  }

  /// Check expiry dates for a specific list of vehicle licenses
  Future<void> checkVehicleExpiries(List<VehicleLicense> vehicleLicenses) async {
    try {
      await _notificationService.checkVehicleExpiries(vehicleLicenses);
    } catch (e) {
      print('Error checking vehicle expiry dates: $e');
    }
  }

  /// Check expiry dates for a specific list of driver licenses
  Future<void> checkDriverExpiries(List<DriverLicense> driverLicenses) async {
    try {
      await _notificationService.checkDriverExpiries(driverLicenses);
    } catch (e) {
      print('Error checking driver expiry dates: $e');
    }
  }

  /// Check expiry dates for a specific list of engine oil services
  Future<void> checkEngineOilServiceExpiries(List<EngineOilService> services) async {
    try {
      await _notificationService.checkEngineOilServiceExpiries(services);
    } catch (e) {
      print('Error checking engine oil service expiry dates: $e');
    }
  }

  /// Check event dates for a specific list of mahal bookings
  Future<void> checkMahalBookingEventDates(List<MahalBooking> bookings) async {
    try {
      await _notificationService.checkMahalBookingEventDates(bookings);
    } catch (e) {
      print('Error checking mahal booking event dates: $e');
    }
  }
}
