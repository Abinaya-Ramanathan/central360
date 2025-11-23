# Notification Setup Summary

## ✅ Implementation Complete

### Vehicle Permit Expiry Notifications

The app now automatically sends notifications when vehicle permits are about to expire (2 days before expiry).

#### How It Works:

1. **On App Startup**:
   - Notification permissions are requested automatically
   - Background service starts checking for expiring permits every 6 hours

2. **Permit Expiry Check**:
   - Checks all vehicle licenses for permit dates
   - If a permit expires in **0-2 days**, a notification is sent
   - Notification message: `"{Vehicle Name} ({Registration Number}) permit is expiring {today/tomorrow/in 2 days}."`

3. **When Vehicle Licenses Are Updated**:
   - Automatically re-checks all permits after saving/updating
   - Sends notifications if any permits are expiring soon

#### Example Notification:
- **Title**: Vehicle Permit Expiry Alert
- **Body**: "Toyota Camry (TN-01-AB-1234) permit is expiring tomorrow."

#### Permissions Required:

**Android**:
- Automatically requested on first launch (Android 13+)
- Permission dialog will appear requesting notification access

**iOS**:
- Automatically requested on first launch
- Permission dialog will appear requesting notification access

**Windows**:
- No explicit permission needed
- May need to allow notifications in Windows Settings > System > Notifications

#### Testing:

To test the notification system:
1. Add a vehicle license with a permit date that's 2 days from today
2. Save the vehicle license
3. A notification should appear immediately (if permission is granted)
4. The notification will also appear once per day until the permit is updated or expires

#### Notification Frequency:
- **Checks once per day** (every 24 hours) in the background
- Immediate checks when data is loaded or updated
- Initial check 5 seconds after app startup

#### Vehicle Service Notifications:
The notification message includes:
- Vehicle Name
- Model
- Service Part Name
- Days until service date

**Example**: "Toyota Camry (2020) - engine oil next service date is tomorrow."

#### Windows Support:
✅ **Windows notifications are fully supported** by `flutter_local_notifications`
- Works automatically without additional configuration
- Shows system notifications in Windows notification center
- No special permissions required for Windows

#### Note:
- Notifications are only sent once per vehicle/date combination to avoid spam
- If a permit date is updated, the system will re-evaluate and send a new notification if needed

