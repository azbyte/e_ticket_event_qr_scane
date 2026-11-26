import 'package:e_ticket_event_qr_scane/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresi: pesan error dari backend harus menyebut detail validasi.
///
/// Sebelumnya klien hanya menampilkan `message` sehingga kegagalan pendaftaran
/// Organizer tampil sebagai "Validation failed" tanpa petunjuk field mana yang
/// salah.
void main() {
  test('detail field validasi disertakan pada pesan error', () {
    final message = buildApiErrorMessage(
      {
        'success': false,
        'message': 'Validation failed',
        'errors': [
          {'field': 'email', 'message': 'Valid email is required'},
        ],
      },
      400,
    );

    expect(message, contains('Validation failed'));
    expect(message, contains('email'));
    expect(message, contains('Valid email is required'));
  });

  test('pesan server dipakai apa adanya bila tidak ada detail field', () {
    expect(
      buildApiErrorMessage(
        {'success': false, 'message': 'Invalid credentials'},
        401,
      ),
      'Invalid credentials',
    );
  });

  test('respons tanpa message memakai status code sebagai fallback', () {
    expect(buildApiErrorMessage(const {}, 500), 'Request failed (500)');
  });

  test('entry error tanpa field tetap ditampilkan pesannya', () {
    final message = buildApiErrorMessage(
      {
        'message': 'Validation failed',
        'errors': [
          {'message': 'Password must be at least 6 characters'},
        ],
      },
      400,
    );

    expect(message, contains('Password must be at least 6 characters'));
    expect(message, isNot(contains('null')));
  });
}
