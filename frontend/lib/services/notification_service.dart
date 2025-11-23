import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../models/vehicle_license.dart';
import '../models/driver_license.dart';
import '../models/engine_oil_service.dart';
import '../models/mahal_booking.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Request notification permission
    await requestNotificationPermission();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialization settings for all platforms (Windows is supported automatically)
    // Windows notifications work without explicit initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      // Windows is automatically supported by flutter_local_notifications
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    _initialized = true;
  }

  /// Request notification permission (required for Android 13+ and iOS)
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    
    if (status.isDenied) {
      final result = await Permission.notification.request();
      return result.isGranted;
    }
    
    return status.isGranted;
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'vehicle_expiry_alerts', // id
      'Vehicle Expiry Alerts', // title
      description: 'Notifications for vehicle permit expiry reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - you can navigate to specific screen here
    print('Notification tapped: ${response.payload}');
  }

  /// Show a notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'vehicle_expiry_alerts',
      'Vehicle Expiry Alerts',
      channelDescription: 'Notifications for vehicle permit expiry reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Windows notifications are automatically supported by flutter_local_notifications
    // No explicit Windows details needed - the plugin handles it automatically
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      // Windows is supported automatically by the plugin
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
  
  /// Track which notifications have been sent to avoid duplicates
  final Set<String> _sentNotifications = {};
  
  /// Generate a unique key for a notification based on type, name, and date
  String _generateNotificationKey(String type, String name, DateTime date) {
    final dateStr = '${date.year}-${date.month}-${date.day}';
    return '${type}_${name}_$dateStr';
  }
  
  /// Clear sent notifications (can be called when checking again after permit update)
  void clearSentNotifications() {
    _sentNotifications.clear();
  }

  /// Check vehicle licenses for expiring dates (2 days before expiry)
  /// Checks all date fields: Permit, Insurance, Fitness, Pollution, Tax
  Future<void> checkVehicleExpiries(List<VehicleLicense> licenses) async {
    if (!await requestNotificationPermission()) {
      return; // Exit if permission not granted
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var license in licenses) {
      final vehicleName = license.name;
      final registrationNumber = license.registrationNumber;

      // Check Permit Date
      if (license.permitDate != null) {
        await _checkAndNotifyDateExpiry(
          date: license.permitDate!,
          vehicleName: vehicleName,
          registrationNumber: registrationNumber,
          dateType: 'permit',
          licenseId: license.id ?? 0,
          today: today,
        );
      }

      // Check Insurance Date
      if (license.insuranceDate != null) {
        await _checkAndNotifyDateExpiry(
          date: license.insuranceDate!,
          vehicleName: vehicleName,
          registrationNumber: registrationNumber,
          dateType: 'insurance',
          licenseId: license.id ?? 0,
          today: today,
        );
      }

      // Check Fitness Date
      if (license.fitnessDate != null) {
        await _checkAndNotifyDateExpiry(
          date: license.fitnessDate!,
          vehicleName: vehicleName,
          registrationNumber: registrationNumber,
          dateType: 'fitness',
          licenseId: license.id ?? 0,
          today: today,
        );
      }

      // Check Pollution Date
      if (license.pollutionDate != null) {
        await _checkAndNotifyDateExpiry(
          date: license.pollutionDate!,
          vehicleName: vehicleName,
          registrationNumber: registrationNumber,
          dateType: 'pollution',
          licenseId: license.id ?? 0,
          today: today,
        );
      }

      // Check Tax Date
      if (license.taxDate != null) {
        await _checkAndNotifyDateExpiry(
          date: license.taxDate!,
          vehicleName: vehicleName,
          registrationNumber: registrationNumber,
          dateType: 'tax',
          licenseId: license.id ?? 0,
          today: today,
        );
      }
    }
  }

  /// Helper method to check date expiry and send notification
  Future<void> _checkAndNotifyDateExpiry({
    required DateTime date,
    required String vehicleName,
    required String registrationNumber,
    required String dateType,
    required int licenseId,
    required DateTime today,
  }) async {
    // Normalize dates to midnight for comparison (only date part, ignore time)
    final expiryDate = DateTime(date.year, date.month, date.day);
    
    // Check if date expires in exactly 2 days or less (2 days before expiry)
    final daysUntilExpiry = expiryDate.difference(today).inDays;
    
    // Send notification if date expires in 0-2 days (today, tomorrow, or in 2 days)
    if (daysUntilExpiry >= 0 && daysUntilExpiry <= 2) {
      // Generate unique key to avoid duplicate notifications
      final notificationKey = _generateNotificationKey('vehicle_${dateType}', vehicleName, expiryDate);
      
      // Only send notification if we haven't sent it already
      if (!_sentNotifications.contains(notificationKey)) {
        final daysText = daysUntilExpiry == 0 
            ? 'today' 
            : daysUntilExpiry == 1 
                ? 'tomorrow' 
                : 'in 2 days';
        
        final dateTypeLabel = dateType.substring(0, 1).toUpperCase() + dateType.substring(1);
        
        await showNotification(
          id: _generateNotificationId('vehicle_$dateType', licenseId),
          title: 'Vehicle $dateTypeLabel Expiry Alert',
          body: '$vehicleName ($registrationNumber) $dateType is expiring $daysText.',
          payload: 'vehicle_${dateType}_${licenseId}',
        );
        
        // Mark this notification as sent
        _sentNotifications.add(notificationKey);
      }
    } else if (daysUntilExpiry < 0) {
      // Date has already expired - remove from sent notifications if it was there
      final notificationKey = _generateNotificationKey('vehicle_$dateType', vehicleName, expiryDate);
      _sentNotifications.remove(notificationKey);
    }
  }

  /// Check driver licenses for expiring dates
  Future<void> checkDriverExpiries(List<DriverLicense> licenses) async {
    if (!await requestNotificationPermission()) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var license in licenses) {
      final driverName = license.driverName;
      final expiryDate = DateTime(
        license.expiryDate.year,
        license.expiryDate.month,
        license.expiryDate.day,
      );

      final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
      final daysUntilExpiry = expiry.difference(today).inDays;

      if (daysUntilExpiry >= 0 && daysUntilExpiry <= 2) {
        final notificationKey = _generateNotificationKey('driver_license', driverName, expiry);
        
        // Only send notification if we haven't sent it already
        if (!_sentNotifications.contains(notificationKey)) {
          final daysText = daysUntilExpiry == 0 
              ? 'today' 
              : daysUntilExpiry == 1 
                  ? 'tomorrow' 
                  : 'in 2 days';
          
          await showNotification(
            id: _generateNotificationId('driver', license.id ?? 0),
            title: 'Driver License Expiring Soon',
            body: '$driverName license is expiring $daysText.',
            payload: 'driver_license_${license.id}',
          );
          
          // Mark this notification as sent
          _sentNotifications.add(notificationKey);
        }
      } else if (daysUntilExpiry < 0) {
        // License has already expired - remove from sent notifications if it was there
        final notificationKey = _generateNotificationKey('driver_license', driverName, expiry);
        _sentNotifications.remove(notificationKey);
      }
    }
  }

  /// Check engine oil services for next service date (2 days before)
  Future<void> checkEngineOilServiceExpiries(List<EngineOilService> services) async {
    if (!await requestNotificationPermission()) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var service in services) {
      final vehicleName = service.vehicleName;
      final model = service.model;
      final servicePartName = service.servicePartName;

      // Check Next Service Date
      if (service.nextServiceDate != null) {
        final nextServiceDate = service.nextServiceDate!;
        final expiryDate = DateTime(nextServiceDate.year, nextServiceDate.month, nextServiceDate.day);
        final daysUntilExpiry = expiryDate.difference(today).inDays;

        if (daysUntilExpiry >= 0 && daysUntilExpiry <= 2) {
          // Include service part name in notification key for uniqueness
          final uniqueKey = '${vehicleName}_$servicePartName';
          final notificationKey = _generateNotificationKey('vehicle_service', uniqueKey, expiryDate);
          
          // Only send notification if we haven't sent it already
          if (!_sentNotifications.contains(notificationKey)) {
            final daysText = daysUntilExpiry == 0 
                ? 'today' 
                : daysUntilExpiry == 1 
                    ? 'tomorrow' 
                    : 'in 2 days';
            
            await showNotification(
              id: _generateNotificationId('service', service.id ?? 0),
              title: 'Vehicle Service Due Alert',
              body: '$vehicleName ($model) - $servicePartName next service date is $daysText.',
              payload: 'vehicle_service_${service.id}',
            );
            
            // Mark this notification as sent
            _sentNotifications.add(notificationKey);
          }
        } else if (daysUntilExpiry < 0) {
          // Service date has already passed - remove from sent notifications if it was there
          final uniqueKey = '${vehicleName}_$servicePartName';
          final notificationKey = _generateNotificationKey('vehicle_service', uniqueKey, expiryDate);
          _sentNotifications.remove(notificationKey);
        }
      }
    }
  }

  /// Check mahal bookings for event date (2 days before)
  Future<void> checkMahalBookingEventDates(List<MahalBooking> bookings) async {
    if (!await requestNotificationPermission()) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var booking in bookings) {
      final bookingId = booking.bookingId ?? 'Unknown';
      final mahalDetail = booking.mahalDetail;
      final clientName = booking.clientName;

      // Check Event Date
      final eventDate = booking.eventDate;
      final expiryDate = DateTime(eventDate.year, eventDate.month, eventDate.day);
      final daysUntilEvent = expiryDate.difference(today).inDays;

      if (daysUntilEvent >= 0 && daysUntilEvent <= 2) {
        final notificationKey = _generateNotificationKey('event', bookingId, expiryDate);
        
        // Only send notification if we haven't sent it already
        if (!_sentNotifications.contains(notificationKey)) {
          final daysText = daysUntilEvent == 0 
              ? 'today' 
              : daysUntilEvent == 1 
                  ? 'tomorrow' 
                  : 'in 2 days';
          
          await showNotification(
            id: _generateNotificationId('event', booking.hashCode),
            title: 'Event Date Reminder',
            body: 'Event for $clientName at $mahalDetail (Booking: $bookingId) is $daysText.',
            payload: 'event_$bookingId',
          );
          
          // Mark this notification as sent
          _sentNotifications.add(notificationKey);
        }
      } else if (daysUntilEvent < 0) {
        // Event date has already passed - remove from sent notifications if it was there
        final notificationKey = _generateNotificationKey('event', bookingId, expiryDate);
        _sentNotifications.remove(notificationKey);
      }
    }
  }

  /// Generate unique notification ID based on type and license ID
  int _generateNotificationId(String type, int licenseId) {
    // Create a unique ID by combining type hash and license ID
    final typeHash = type.hashCode;
    return (typeHash.abs() % 10000) * 10000 + (licenseId % 10000);
  }
}
