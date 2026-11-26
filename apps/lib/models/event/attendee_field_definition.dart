/// Definisi satu field data peserta (kontrak D1-5).
///
/// Bentuk JSON: `{ "key", "label", "type", "required", "options" }`.
/// Kompatibel mundur dengan array string legacy (`['name','email','phone']`):
/// string dipetakan ke field teks dengan label default.
class AttendeeFieldDefinition {
  const AttendeeFieldDefinition({
    required this.key,
    required this.label,
    this.type = typeText,
    this.required = false,
    this.options = const <String>[],
  });

  static const String typeText = 'text';
  static const String typeTextarea = 'textarea';
  static const String typeNumber = 'number';
  static const String typeDate = 'date';
  static const String typeSelect = 'select';
  static const String typeCheckbox = 'checkbox';

  static const List<String> supportedTypes = <String>[
    typeText,
    typeTextarea,
    typeNumber,
    typeDate,
    typeSelect,
    typeCheckbox,
  ];

  static const Map<String, String> _defaultLabels = <String, String>{
    'name': 'Nama lengkap',
    'email': 'Email',
    'phone': 'Nomor telepon',
    'organization': 'Instansi/organisasi',
  };

  /// Nama & email adalah kolom wajib pada tabel `attendees`.
  static const Set<String> _alwaysRequired = <String>{'name', 'email'};

  final String key;
  final String label;
  final String type;
  final bool required;
  final List<String> options;

  bool get isCheckbox => type == typeCheckbox;
  bool get isSelect => type == typeSelect;
  bool get isNumber => type == typeNumber;
  bool get isDate => type == typeDate;
  bool get isMultiline => type == typeTextarea;
  bool get isEmail => key == 'email';
  bool get isPhone => key == 'phone';

  /// Field kolom `attendees` (bukan `custom_fields`).
  bool get isColumnField =>
      key == 'name' || key == 'email' || key == 'phone';

  factory AttendeeFieldDefinition.fromKey(String key) {
    final trimmed = key.trim();
    return AttendeeFieldDefinition(
      key: trimmed,
      label: _defaultLabels[trimmed] ?? trimmed,
      required: _alwaysRequired.contains(trimmed),
    );
  }

  factory AttendeeFieldDefinition.fromJson(dynamic raw) {
    if (raw is String) return AttendeeFieldDefinition.fromKey(raw);
    if (raw is Map) {
      final key = raw['key']?.toString().trim() ?? '';
      if (key.isEmpty) {
        throw const FormatException('Field peserta tanpa kunci.');
      }
      final rawType = raw['type']?.toString().toLowerCase() ?? typeText;
      final type = supportedTypes.contains(rawType) ? rawType : typeText;
      final rawOptions = raw['options'];
      return AttendeeFieldDefinition(
        key: key,
        label: raw['label']?.toString() ?? _defaultLabels[key] ?? key,
        type: type,
        required: _alwaysRequired.contains(key) || raw['required'] == true,
        options: rawOptions is List
            ? rawOptions.map((option) => option.toString()).toList(
                growable: false,
              )
            : const <String>[],
      );
    }
    throw const FormatException('Definisi field peserta tidak valid.');
  }

  /// Baca `attendee_fields` (array objek atau array string legacy).
  static List<AttendeeFieldDefinition> listFromJson(dynamic raw) {
    if (raw is! List) return const <AttendeeFieldDefinition>[];
    return raw
        .map(AttendeeFieldDefinition.fromJson)
        .toList(growable: false);
  }

  /// Turunkan definisi dari daftar kunci (event lama / fixture).
  static List<AttendeeFieldDefinition> listFromKeys(Iterable<String> keys) =>
      keys.map(AttendeeFieldDefinition.fromKey).toList(growable: false);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'label': label,
    'type': type,
    'required': required,
    if (options.isNotEmpty) 'options': options,
  };

  @override
  String toString() => 'AttendeeFieldDefinition($key, $type, required: $required)';
}

/// Definisi field peserta default yang wajib ada pada setiap event.
///
/// `name` dan `email` adalah kolom wajib tabel `attendees` dan divalidasi ulang
/// server (`REQUIRED_ATTENDEE_FIELD_KEYS`), sehingga keduanya selalu disertakan
/// ketika event tidak menyimpan definisi bertipe.
class OrganizerAttendeeDefaults {
  OrganizerAttendeeDefaults._();

  static const List<AttendeeFieldDefinition> definitions =
      <AttendeeFieldDefinition>[
        AttendeeFieldDefinition(
          key: 'name',
          label: 'Nama lengkap',
          required: true,
        ),
        AttendeeFieldDefinition(
          key: 'email',
          label: 'Email',
          required: true,
        ),
      ];
}
