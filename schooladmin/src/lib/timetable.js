/*
 * Shared weekly-timetable constants.
 * Single source of truth for the schedule shape — used by the mock backend
 * (lib/mock.js) and the Timetable page (pages/TimetablePage.jsx).
 *
 * Period times are per-school data: each school stores its own list of
 * { n, time } periods and the timetable API returns them. DEFAULT_PERIODS is
 * only the fallback for schools without a configured schedule.
 */

export const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']

export const DEFAULT_PERIODS = [
  { n: 1, time: '8:30 – 9:15' },
  { n: 2, time: '9:15 – 10:00' },
  { n: 3, time: '10:00 – 10:45' },
  { n: 4, time: '11:00 – 11:45' },
  { n: 5, time: '11:45 – 12:30' },
  { n: 6, time: '13:00 – 13:45' },
  { n: 7, time: '13:45 – 14:30' },
  { n: 8, time: '14:30 – 15:15' },
]
