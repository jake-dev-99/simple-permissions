part of 'permission.dart';

/// Permissions related to contacts access.
sealed class ContactsPermission extends Permission {
  const ContactsPermission();
}

/// Read the device contact book.
///
/// - **Android**: `android.permission.READ_CONTACTS`
/// - **iOS**: `CNAuthorizationStatus` for `.contacts`
class ReadContacts extends ContactsPermission {
  const ReadContacts();

  @override
  String get identifier => 'read_contacts';
}

/// Write/modify the device contact book.
///
/// - **Android**: `android.permission.WRITE_CONTACTS`
/// - **iOS**: Included in contacts authorization (same as read)
class WriteContacts extends ContactsPermission {
  const WriteContacts();

  @override
  String get identifier => 'write_contacts';
}
