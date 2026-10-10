/// Mirrors mobile/src/constants/nudges.ts.
class NudgeTemplate {
  const NudgeTemplate({
    required this.type,
    required this.label,
    required this.time,
    required this.message,
  });

  final String type;
  final String label;
  final String time;
  final String message;
}

const defaultNudges = [
  NudgeTemplate(
    type: 'MORNING_CHECK',
    label: 'Morning check-in',
    time: '07:30',
    message: "Quick peek at today's missions before the day starts.",
  ),
  NudgeTemplate(
    type: 'AFTER_SCHOOL',
    label: 'After school nudge',
    time: '16:00',
    message: 'Tidy-up or a tiny task before play time.',
  ),
  NudgeTemplate(
    type: 'EVENING_RESET',
    label: 'Evening reset',
    time: '19:30',
    message: 'Wrap up chores and get ready for tomorrow.',
  ),
];

NudgeTemplate? nudgeTemplateFor(String type) {
  for (final template in defaultNudges) {
    if (template.type == type) return template;
  }
  return null;
}
