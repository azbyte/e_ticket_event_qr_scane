/// Form input validators shared across feature screens.
///
/// Returns null when input is valid, otherwise an error message string.
class InputValidator {
  InputValidator._();

  static String? required(String? value, {String field = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, field: 'Email');
    if (requiredError != null) return requiredError;
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value!)) {
      return 'Format email tidak valid.';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    final requiredError = required(value, field: 'Kata sandi');
    if (requiredError != null) return requiredError;
    if (value!.length < minLength) {
      return 'Kata sandi minimal $minLength karakter.';
    }
    return null;
  }

  static String? positiveInteger(String? value, {String field = 'Jumlah'}) {
    final requiredError = required(value, field: field);
    if (requiredError != null) return requiredError;
    final parsed = int.tryParse(value!);
    if (parsed == null || parsed <= 0) {
      return '$field harus berupa angka lebih besar dari nol.';
    }
    return null;
  }
}
