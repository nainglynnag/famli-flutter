/// Common real-world IANA timezones and locations for quick selection,
/// searching, and auto-syncing in the profile screen.
class TimezoneOption {
  const TimezoneOption({
    required this.name,
    required this.offset,
    required this.city,
    required this.country,
    this.region = 'Asia & Pacific',
    this.flag = '🌐',
  });

  /// The standard IANA timezone identifier (e.g. 'Asia/Yangon', 'Asia/Bangkok')
  final String name;

  /// The GMT/UTC offset string (e.g. 'GMT+06:30', 'GMT+07:00')
  final String offset;

  /// Primary city name (e.g. 'Yangon', 'Bangkok')
  final String city;

  /// Country or territory name (e.g. 'Myanmar', 'Thailand')
  final String country;

  /// Geographic region grouping
  final String region;

  /// Flag emoji for country
  final String flag;

  String get locationLabel => '$city, $country';
  String get fullLabel => '$city, $country ($offset)';

  /// Parsed duration of this offset from UTC
  Duration get offsetDuration {
    if (offset == 'UTC' || offset == 'GMT') return Duration.zero;
    final clean = offset.replaceAll('GMT', '').replaceAll('UTC', '').trim();
    if (clean.isEmpty) return Duration.zero;
    final isNegative = clean.startsWith('-');
    final cleanNum = isNegative ? clean.substring(1) : (clean.startsWith('+') ? clean.substring(1) : clean);
    final parts = cleanNum.split(':');
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final totalMinutes = hours * 60 + minutes;
    return Duration(minutes: isNegative ? -totalMinutes : totalMinutes);
  }

  /// Calculates the current formatted wall-clock time in this timezone (e.g. '10:05 PM')
  String get currentTimeFormatted {
    final utc = DateTime.now().toUtc();
    final local = utc.add(offsetDuration);
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}

/// Comprehensive real-world timezones with locations, matching mobile and laptop OS settings.
const List<TimezoneOption> commonTimezones = [
  // --- Southeast Asia & South Asia ---
  TimezoneOption(
    name: 'Asia/Yangon',
    offset: 'GMT+06:30',
    city: 'Yangon',
    country: 'Myanmar',
    region: 'Asia & Pacific',
    flag: '🇲🇲',
  ),
  TimezoneOption(
    name: 'Asia/Bangkok',
    offset: 'GMT+07:00',
    city: 'Bangkok',
    country: 'Thailand',
    region: 'Asia & Pacific',
    flag: '🇹🇭',
  ),
  TimezoneOption(
    name: 'Asia/Singapore',
    offset: 'GMT+08:00',
    city: 'Singapore',
    country: 'Singapore',
    region: 'Asia & Pacific',
    flag: '🇸🇬',
  ),
  TimezoneOption(
    name: 'Asia/Kuala_Lumpur',
    offset: 'GMT+08:00',
    city: 'Kuala Lumpur',
    country: 'Malaysia',
    region: 'Asia & Pacific',
    flag: '🇲🇾',
  ),
  TimezoneOption(
    name: 'Asia/Jakarta',
    offset: 'GMT+07:00',
    city: 'Jakarta',
    country: 'Indonesia',
    region: 'Asia & Pacific',
    flag: '🇮🇩',
  ),
  TimezoneOption(
    name: 'Asia/Makassar',
    offset: 'GMT+08:00',
    city: 'Makassar',
    country: 'Indonesia',
    region: 'Asia & Pacific',
    flag: '🇮🇩',
  ),
  TimezoneOption(
    name: 'Asia/Jayapura',
    offset: 'GMT+09:00',
    city: 'Jayapura',
    country: 'Indonesia',
    region: 'Asia & Pacific',
    flag: '🇮🇩',
  ),
  TimezoneOption(
    name: 'Asia/Ho_Chi_Minh',
    offset: 'GMT+07:00',
    city: 'Ho Chi Minh City',
    country: 'Vietnam',
    region: 'Asia & Pacific',
    flag: '🇻🇳',
  ),
  TimezoneOption(
    name: 'Asia/Manila',
    offset: 'GMT+08:00',
    city: 'Manila',
    country: 'Philippines',
    region: 'Asia & Pacific',
    flag: '🇵🇭',
  ),
  TimezoneOption(
    name: 'Asia/Phnom_Penh',
    offset: 'GMT+07:00',
    city: 'Phnom Penh',
    country: 'Cambodia',
    region: 'Asia & Pacific',
    flag: '🇰🇭',
  ),
  TimezoneOption(
    name: 'Asia/Vientiane',
    offset: 'GMT+07:00',
    city: 'Vientiane',
    country: 'Laos',
    region: 'Asia & Pacific',
    flag: '🇱🇦',
  ),
  TimezoneOption(
    name: 'Asia/Kolkata',
    offset: 'GMT+05:30',
    city: 'New Delhi / Kolkata',
    country: 'India',
    region: 'Asia & Pacific',
    flag: '🇮🇳',
  ),
  TimezoneOption(
    name: 'Asia/Dhaka',
    offset: 'GMT+06:00',
    city: 'Dhaka',
    country: 'Bangladesh',
    region: 'Asia & Pacific',
    flag: '🇧🇩',
  ),
  TimezoneOption(
    name: 'Asia/Kathmandu',
    offset: 'GMT+05:45',
    city: 'Kathmandu',
    country: 'Nepal',
    region: 'Asia & Pacific',
    flag: '🇳🇵',
  ),
  TimezoneOption(
    name: 'Asia/Colombo',
    offset: 'GMT+05:30',
    city: 'Colombo',
    country: 'Sri Lanka',
    region: 'Asia & Pacific',
    flag: '🇱🇰',
  ),
  TimezoneOption(
    name: 'Asia/Karachi',
    offset: 'GMT+05:00',
    city: 'Karachi / Islamabad',
    country: 'Pakistan',
    region: 'Asia & Pacific',
    flag: '🇵🇰',
  ),

  // --- East Asia & Pacific ---
  TimezoneOption(
    name: 'Asia/Tokyo',
    offset: 'GMT+09:00',
    city: 'Tokyo',
    country: 'Japan',
    region: 'Asia & Pacific',
    flag: '🇯🇵',
  ),
  TimezoneOption(
    name: 'Asia/Seoul',
    offset: 'GMT+09:00',
    city: 'Seoul',
    country: 'South Korea',
    region: 'Asia & Pacific',
    flag: '🇰🇷',
  ),
  TimezoneOption(
    name: 'Asia/Shanghai',
    offset: 'GMT+08:00',
    city: 'Beijing / Shanghai',
    country: 'China',
    region: 'Asia & Pacific',
    flag: '🇨🇳',
  ),
  TimezoneOption(
    name: 'Asia/Hong_Kong',
    offset: 'GMT+08:00',
    city: 'Hong Kong',
    country: 'Hong Kong',
    region: 'Asia & Pacific',
    flag: '🇭🇰',
  ),
  TimezoneOption(
    name: 'Asia/Taipei',
    offset: 'GMT+08:00',
    city: 'Taipei',
    country: 'Taiwan',
    region: 'Asia & Pacific',
    flag: '🇹🇼',
  ),
  TimezoneOption(
    name: 'Australia/Sydney',
    offset: 'GMT+10:00',
    city: 'Sydney',
    country: 'Australia',
    region: 'Asia & Pacific',
    flag: '🇦🇺',
  ),
  TimezoneOption(
    name: 'Australia/Melbourne',
    offset: 'GMT+10:00',
    city: 'Melbourne',
    country: 'Australia',
    region: 'Asia & Pacific',
    flag: '🇦🇺',
  ),
  TimezoneOption(
    name: 'Australia/Perth',
    offset: 'GMT+08:00',
    city: 'Perth',
    country: 'Australia',
    region: 'Asia & Pacific',
    flag: '🇦🇺',
  ),
  TimezoneOption(
    name: 'Australia/Adelaide',
    offset: 'GMT+09:30',
    city: 'Adelaide',
    country: 'Australia',
    region: 'Asia & Pacific',
    flag: '🇦🇺',
  ),
  TimezoneOption(
    name: 'Australia/Darwin',
    offset: 'GMT+09:30',
    city: 'Darwin',
    country: 'Australia',
    region: 'Asia & Pacific',
    flag: '🇦🇺',
  ),
  TimezoneOption(
    name: 'Pacific/Auckland',
    offset: 'GMT+12:00',
    city: 'Auckland',
    country: 'New Zealand',
    region: 'Asia & Pacific',
    flag: '🇳🇿',
  ),
  TimezoneOption(
    name: 'Pacific/Fiji',
    offset: 'GMT+12:00',
    city: 'Suva',
    country: 'Fiji',
    region: 'Asia & Pacific',
    flag: '🇫🇯',
  ),

  // --- Middle East ---
  TimezoneOption(
    name: 'Asia/Dubai',
    offset: 'GMT+04:00',
    city: 'Dubai',
    country: 'United Arab Emirates',
    region: 'Europe & Africa',
    flag: '🇦🇪',
  ),
  TimezoneOption(
    name: 'Asia/Riyadh',
    offset: 'GMT+03:00',
    city: 'Riyadh',
    country: 'Saudi Arabia',
    region: 'Europe & Africa',
    flag: '🇸🇦',
  ),
  TimezoneOption(
    name: 'Asia/Qatar',
    offset: 'GMT+03:00',
    city: 'Doha',
    country: 'Qatar',
    region: 'Europe & Africa',
    flag: '🇶🇦',
  ),

  // --- Europe & Africa ---
  TimezoneOption(
    name: 'Europe/London',
    offset: 'GMT',
    city: 'London',
    country: 'United Kingdom',
    region: 'Europe & Africa',
    flag: '🇬🇧',
  ),
  TimezoneOption(
    name: 'Europe/Paris',
    offset: 'GMT+01:00',
    city: 'Paris',
    country: 'France',
    region: 'Europe & Africa',
    flag: '🇫🇷',
  ),
  TimezoneOption(
    name: 'Europe/Berlin',
    offset: 'GMT+01:00',
    city: 'Berlin',
    country: 'Germany',
    region: 'Europe & Africa',
    flag: '🇩🇪',
  ),
  TimezoneOption(
    name: 'Europe/Amsterdam',
    offset: 'GMT+01:00',
    city: 'Amsterdam',
    country: 'Netherlands',
    region: 'Europe & Africa',
    flag: '🇳🇱',
  ),
  TimezoneOption(
    name: 'Europe/Madrid',
    offset: 'GMT+01:00',
    city: 'Madrid',
    country: 'Spain',
    region: 'Europe & Africa',
    flag: '🇪🇸',
  ),
  TimezoneOption(
    name: 'Europe/Rome',
    offset: 'GMT+01:00',
    city: 'Rome',
    country: 'Italy',
    region: 'Europe & Africa',
    flag: '🇮🇹',
  ),
  TimezoneOption(
    name: 'Europe/Zurich',
    offset: 'GMT+01:00',
    city: 'Zurich',
    country: 'Switzerland',
    region: 'Europe & Africa',
    flag: '🇨🇭',
  ),
  TimezoneOption(
    name: 'Europe/Stockholm',
    offset: 'GMT+01:00',
    city: 'Stockholm',
    country: 'Sweden',
    region: 'Europe & Africa',
    flag: '🇸🇪',
  ),
  TimezoneOption(
    name: 'Europe/Athens',
    offset: 'GMT+02:00',
    city: 'Athens',
    country: 'Greece',
    region: 'Europe & Africa',
    flag: '🇬🇷',
  ),
  TimezoneOption(
    name: 'Europe/Istanbul',
    offset: 'GMT+03:00',
    city: 'Istanbul',
    country: 'Turkey',
    region: 'Europe & Africa',
    flag: '🇹🇷',
  ),
  TimezoneOption(
    name: 'Africa/Cairo',
    offset: 'GMT+02:00',
    city: 'Cairo',
    country: 'Egypt',
    region: 'Europe & Africa',
    flag: '🇪🇬',
  ),
  TimezoneOption(
    name: 'Africa/Johannesburg',
    offset: 'GMT+02:00',
    city: 'Johannesburg',
    country: 'South Africa',
    region: 'Europe & Africa',
    flag: '🇿🇦',
  ),
  TimezoneOption(
    name: 'Africa/Lagos',
    offset: 'GMT+01:00',
    city: 'Lagos',
    country: 'Nigeria',
    region: 'Europe & Africa',
    flag: '🇳🇬',
  ),
  TimezoneOption(
    name: 'Africa/Nairobi',
    offset: 'GMT+03:00',
    city: 'Nairobi',
    country: 'Kenya',
    region: 'Europe & Africa',
    flag: '🇰🇪',
  ),

  // --- Americas ---
  TimezoneOption(
    name: 'America/New_York',
    offset: 'GMT-05:00',
    city: 'New York',
    country: 'United States',
    region: 'Americas',
    flag: '🇺🇸',
  ),
  TimezoneOption(
    name: 'America/Chicago',
    offset: 'GMT-06:00',
    city: 'Chicago',
    country: 'United States',
    region: 'Americas',
    flag: '🇺🇸',
  ),
  TimezoneOption(
    name: 'America/Denver',
    offset: 'GMT-07:00',
    city: 'Denver',
    country: 'United States',
    region: 'Americas',
    flag: '🇺🇸',
  ),
  TimezoneOption(
    name: 'America/Los_Angeles',
    offset: 'GMT-08:00',
    city: 'Los Angeles',
    country: 'United States',
    region: 'Americas',
    flag: '🇺🇸',
  ),
  TimezoneOption(
    name: 'America/Anchorage',
    offset: 'GMT-09:00',
    city: 'Anchorage',
    country: 'United States',
    region: 'Americas',
    flag: '🇺🇸',
  ),
  TimezoneOption(
    name: 'Pacific/Honolulu',
    offset: 'GMT-10:00',
    city: 'Honolulu',
    country: 'United States',
    region: 'Americas',
    flag: '🇺🇸',
  ),
  TimezoneOption(
    name: 'America/Toronto',
    offset: 'GMT-05:00',
    city: 'Toronto',
    country: 'Canada',
    region: 'Americas',
    flag: '🇨🇦',
  ),
  TimezoneOption(
    name: 'America/Vancouver',
    offset: 'GMT-08:00',
    city: 'Vancouver',
    country: 'Canada',
    region: 'Americas',
    flag: '🇨🇦',
  ),
  TimezoneOption(
    name: 'America/Mexico_City',
    offset: 'GMT-06:00',
    city: 'Mexico City',
    country: 'Mexico',
    region: 'Americas',
    flag: '🇲🇽',
  ),
  TimezoneOption(
    name: 'America/Sao_Paulo',
    offset: 'GMT-03:00',
    city: 'São Paulo',
    country: 'Brazil',
    region: 'Americas',
    flag: '🇧🇷',
  ),
  TimezoneOption(
    name: 'America/Argentina/Buenos_Aires',
    offset: 'GMT-03:00',
    city: 'Buenos Aires',
    country: 'Argentina',
    region: 'Americas',
    flag: '🇦🇷',
  ),
  TimezoneOption(
    name: 'America/Bogota',
    offset: 'GMT-05:00',
    city: 'Bogotá',
    country: 'Colombia',
    region: 'Americas',
    flag: '🇨🇴',
  ),
  TimezoneOption(
    name: 'America/Santiago',
    offset: 'GMT-04:00',
    city: 'Santiago',
    country: 'Chile',
    region: 'Americas',
    flag: '🇨🇱',
  ),

  // --- Global / Reference ---
  TimezoneOption(
    name: 'UTC',
    offset: 'UTC',
    city: 'Coordinated Universal Time',
    country: 'Global Reference',
    region: 'Global',
    flag: '🌐',
  ),
];

/// Finds a timezone by IANA name, or returns null if not found.
TimezoneOption? findTimezoneByName(String? name) {
  if (name == null || name.isEmpty) return null;
  final normalized = name.trim();
  for (final tz in commonTimezones) {
    if (tz.name.equalsIgnoreCase(normalized)) return tz;
  }
  // Try partial city or country match
  for (final tz in commonTimezones) {
    if (tz.name.toLowerCase().endsWith(normalized.toLowerCase())) return tz;
  }
  return null;
}

/// Finds the closest matching timezone by duration offset.
TimezoneOption? findTimezoneByOffset(Duration offset) {
  for (final tz in commonTimezones) {
    if (tz.offsetDuration == offset) return tz;
  }
  return null;
}

/// Searches the timezone catalog by query across city, country, offset, and IANA identifier.
List<TimezoneOption> searchTimezones(String query, {String? regionFilter}) {
  final clean = query.trim().toLowerCase();
  return commonTimezones.where((tz) {
    if (regionFilter != null && regionFilter != 'All' && tz.region != regionFilter) {
      return false;
    }
    if (clean.isEmpty) return true;
    return tz.city.toLowerCase().contains(clean) ||
        tz.country.toLowerCase().contains(clean) ||
        tz.offset.toLowerCase().contains(clean) ||
        tz.name.toLowerCase().contains(clean);
  }).toList();
}

extension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
