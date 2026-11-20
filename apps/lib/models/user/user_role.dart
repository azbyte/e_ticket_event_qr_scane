/// User roles defined in PRD section 2.
enum UserRole {
  attendee,
  organizer,
  staff,
  admin;

  String get label {
    switch (this) {
      case UserRole.attendee:
        return 'Peserta';
      case UserRole.organizer:
        return 'Penyelenggara';
      case UserRole.staff:
        return 'Staf Event';
      case UserRole.admin:
        return 'Admin Platform';
    }
  }

  static UserRole? fromString(String? value) {
    switch (value) {
      case 'attendee':
      // Alias legacy backend (`USER_ROLES.CUSTOMER`). PRD §2.4: Participant
      // tidak memiliki akun/dashboard, sehingga nilai lama ini dipetakan
      // eksplisit ke role tanpa hak istimewa alih-alih mengandalkan fallback.
      case 'customer':
        return UserRole.attendee;
      case 'organizer':
        return UserRole.organizer;
      case 'staff':
        return UserRole.staff;
      case 'admin':
        return UserRole.admin;
      default:
        return null;
    }
  }
}
