// Quick verification of the demo seed data (run with `flutter pub run tool/check_seed.dart`).
import 'package:demoapp/services/local_db.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  final db = await LocalDb.instance;

  Future<void> dump(String table) async {
    final rows = await db.query(table);
    print('-- $table (${rows.length}) --');
    for (final r in rows.take(30)) {
      print('  $r');
    }
  }

  await dump('groups');
  await dump('instructors');
  await dump('users');
  await dump('students');
  await dump('schedules');
  await dump('attendance');
  await dump('plans');
  await dump('submissions');

  // Spot checks
  final groups = await db.query('groups');
  assert(groups.length == 3, 'expected 3 groups');
  final robert = await db.query('users', where: 'email = ?', whereArgs: ['robert.johnson@school.com']);
  assert(robert.isNotEmpty && robert.first['role'] == 'Instructor');
  final sarah = await db.query('users', where: 'email = ?', whereArgs: ['sarah.mitchell@school.com']);
  assert(sarah.isNotEmpty && sarah.first['role'] == 'Instructor');
  final alex = await db.query('users', where: 'email = ?', whereArgs: ['alex.smith@school.com']);
  assert(alex.isNotEmpty && alex.first['role'] == 'Student');

  // Schedules per group (expect 30 each: 6 weeks x 5 days)
  for (final g in groups) {
    final n = await db.query('schedules', where: 'group_id = ?', whereArgs: [g['id']]);
    print('group ${g['name']}: ${n.length} schedules, course=${n.first['course_name']}');
    assert(n.length == 30, 'expected 30 schedules for ${g['name']}');
  }

  // Attendance must not include today or the future
  final today = DateTime.now();
  final fut = await db.rawQuery(
      "SELECT COUNT(*) c FROM attendance WHERE date >= ?",
      ['${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}']);
  print('attendance rows on/after today: ${fut.first['c']}');
  assert(fut.first['c'] == 0, 'no future attendance allowed');

  // Attendance must be linked to schedules (course-wise breakdown)
  final nullSched = await db.rawQuery('SELECT COUNT(*) c FROM attendance WHERE schedule_id IS NULL');
  print('attendance rows without schedule: ${nullSched.first['c']}');
  assert(nullSched.first['c'] == 0, 'attendance must reference a schedule');

  print('\nALL SEED CHECKS PASSED ✓');
}
