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
