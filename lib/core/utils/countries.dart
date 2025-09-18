// NOTE: Seed with your most-used; extend to full list later.
// Key = ISO2
const Map<String, String> kIso2ToName = {
  'NG': 'Nigeria',
  'KE': 'Kenya',
  'US': 'United States',
  'GB': 'United Kingdom',
  'ZA': 'South Africa',
  'GH': 'Ghana',
  'CM': 'Cameroon',
  'CA': 'Canada',
  'DE': 'Germany',
  'FR': 'France',
  'BR': 'Brazil',
  'IN': 'India',
  'JP': 'Japan',
  'AE': 'United Arab Emirates',
  // … add full list (recommended)
};

final Map<String, String> kNameToIso2 = {
  for (final e in kIso2ToName.entries) e.value.toUpperCase(): e.key,
};

String isoToFlagEmoji(String iso) {
  final up = iso.toUpperCase();
  if (up.length != 2) return '🏳️';
  const base = 0x1F1E6;
  return String.fromCharCode(base + (up.codeUnitAt(0) - 65)) +
      String.fromCharCode(base + (up.codeUnitAt(1) - 65));
}

// Accepts ISO2 ("KE") or name ("KENYA"/"Kenya") → ISO2 or null.
String? normalizeCountryToIso2(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final s = raw.trim();
  if (s.length == 2 && kIso2ToName.containsKey(s.toUpperCase()))
    return s.toUpperCase();
  final byName = kNameToIso2[s.toUpperCase()];
  return byName; // may be null
}

String countryDisplayName(String? iso2) => iso2 == null
    ? 'All Countries'
    : (kIso2ToName[iso2.toUpperCase()] ?? 'Unknown');

// For listing in a bottom sheet
List<MapEntry<String, String>> allCountriesSorted() {
  final list = kIso2ToName.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return list;
}
