/// Ports api/src/constants/nudges.ts.
///
/// These are also the fallback values: a child with no stored nudge settings
/// reads these instead of having them written on first load, because the rules
/// make nudgeSettings parent-only.
const List<Map<String, String>> defaultNudgeTemplates = [
  {
    'type': 'MORNING_CHECK',
    'label': 'Morning check-in',
    'time': '07:30',
    'message': "Quick peek at today's missions before the day starts.",
  },
  {
    'type': 'AFTER_SCHOOL',
    'label': 'After school nudge',
    'time': '16:00',
    'message': 'Tidy-up or a tiny task before play time.',
  },
  {
    'type': 'EVENING_RESET',
    'label': 'Evening reset',
    'time': '19:30',
    'message': 'Wrap up chores and get ready for tomorrow.',
  },
];
