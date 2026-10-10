/// Input validation for the SIM-swap API (mirrors the CAMARA schemas).
///
/// E.164: `^\+[1-9][0-9]{4,14}$`. maxAge: integer 1..2400.
/// Phone numbers are masked (`+34******3334`) before logging/responding.
library;

final _e164 = RegExp(r'^\+[1-9][0-9]{4,14}$');

const camaraMinMaxAge = 1;
const camaraMaxMaxAge = 2400;
const appDefaultLookbackHours = 72;

bool isValidE164(String phone) => _e164.hasMatch(phone);

/// Log/response-safe masked phone, e.g. `+34******3334`.
String? maskPhone(String? phone) {
  if (phone == null || phone.isEmpty) return null;
  if (phone.length <= 6) return '***';
  return '${phone.substring(0, 3)}******${phone.substring(phone.length - 4)}';
}

/// Parses a CAMARA maxAge from decoded JSON. Throws [FormatException] on
/// non-integers, bools, or values outside 1..2400 — fail fast before any
/// token or API call.
int parseMaxAge(dynamic value) {
  if (value is! int) {
    throw FormatException('maxAge must be an integer 1..2400, got $value');
  }
  if (value < camaraMinMaxAge || value > camaraMaxMaxAge) {
    throw FormatException('maxAge $value outside range 1..2400');
  }
  return value;
}

/// Parses an RFC3339 datetime or returns null. Throws [FormatException]
/// on non-string or malformed values.
DateTime? parseCamaraDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is! String) {
    throw FormatException('latestSimChange must be a string or null');
  }
  try {
    return DateTime.parse(raw).toUtc();
  } on FormatException {
    throw FormatException('Invalid latestSimChange datetime: $raw');
  }
}
