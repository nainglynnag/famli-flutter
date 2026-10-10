/// Ported from api/src/routes/auth.ts STARTER_TEMPLATES.
///
/// The Express backend seeded these inside the registration transaction. With
/// no server, the client writes them as part of the registration batch so a new
/// family does not land on an empty app.
const List<Map<String, dynamic>> starterTemplates = [
  {
    'name': 'Morning Routine',
    'description': 'Start weekdays with focus.',
    'frequency': 'DAILY',
    'rewardNote': 'Complete all for +3 seeds',
    'daysOfWeek': ['MON', 'TUE', 'WED', 'THU', 'FRI'],
    'items': [
      {'title': 'Brush Teeth', 'icon': '🦷', 'points': 1},
      {'title': 'Tidy Bed', 'icon': '🛏️', 'points': 1},
      {'title': 'Change School Clothes', 'icon': '👕', 'points': 1},
      {'title': 'Prepare School Bag', 'icon': '🎒', 'points': 2},
    ],
  },
  {
    'name': 'After School Routine',
    'description': 'Wind down after classes.',
    'frequency': 'DAILY',
    'daysOfWeek': ['MON', 'TUE', 'WED', 'THU', 'FRI'],
    'items': [
      {'title': 'Change Clothes', 'icon': '👚', 'points': 1},
      {'title': 'Shower Time', 'icon': '🚿', 'points': 2},
      {'title': 'Do Homework', 'icon': '📘', 'points': 3},
    ],
  },
  {
    'name': 'Weekend Routine',
    'description': 'Slow weekend rhythm.',
    'frequency': 'DAILY',
    'daysOfWeek': ['SAT', 'SUN'],
    'items': [
      {'title': 'Tidy Room', 'icon': '🧹', 'points': 2},
      {'title': 'Read a Book', 'icon': '📖', 'points': 2},
    ],
  },
];
