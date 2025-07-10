import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  factory DatabaseService() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'savage_streak.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        reason TEXT NOT NULL,
        tone TEXT NOT NULL,
        plan TEXT DEFAULT 'free',
        started_at INTEGER NOT NULL,
        reminder_time TEXT,
        current_streak INTEGER DEFAULT 0,
        consecutive_misses INTEGER DEFAULT 0,
        escalation_state INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE entry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        entry_date INTEGER NOT NULL,
        status TEXT DEFAULT 'pending',
        roast_screen TEXT DEFAULT '',
        roast_done TEXT DEFAULT '',
        roast_missed TEXT DEFAULT '',
        FOREIGN KEY (habit_id) REFERENCES habit (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE archive_habit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        reason TEXT NOT NULL,
        tone TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        final_streak INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE archive_entry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        archive_habit_id INTEGER NOT NULL,
        entry_date INTEGER NOT NULL,
        status TEXT NOT NULL,
        roast_screen TEXT DEFAULT '',
        roast_done TEXT DEFAULT '',
        roast_missed TEXT DEFAULT '',
        FOREIGN KEY (archive_habit_id) REFERENCES archive_habit (id) ON DELETE CASCADE
      )
    ''');
  }

  // Habit Operations
  Future<int> insertHabit(HabitModel habit) async {
    final db = await database;
    return await db.insert('habit', habit.toMap());
  }

  Future<HabitModel?> getCurrentHabit() async {
    final db = await database;
    final maps = await db.query('habit', limit: 1, orderBy: 'id DESC');
    if (maps.isEmpty) return null;
    return HabitModel.fromMap(maps.first);
  }

  Future<void> updateHabit(HabitModel habit) async {
    final db = await database;
    await db.update(
      'habit',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<void> deleteHabit(int id) async {
    final db = await database;
    await db.delete('habit', where: 'id = ?', whereArgs: [id]);
  }

  // Entry Operations
  Future<int> insertEntry(EntryModel entry) async {
    final db = await database;
    return await db.insert('entry', entry.toMap());
  }

  Future<EntryModel?> getTodayEntry(int habitId) async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final maps = await db.query(
      'entry',
      where: 'habit_id = ? AND entry_date >= ? AND entry_date < ?',
      whereArgs: [habitId, startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return EntryModel.fromMap(maps.first);
  }

  Future<List<EntryModel>> getEntriesForMonth(int habitId, DateTime month) async {
    final db = await database;
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1);

    final maps = await db.query(
      'entry',
      where: 'habit_id = ? AND entry_date >= ? AND entry_date < ?',
      whereArgs: [habitId, startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch],
      orderBy: 'entry_date ASC',
    );

    return maps.map((map) => EntryModel.fromMap(map)).toList();
  }

  Future<List<EntryModel>> getRecentEntries(int habitId, int limit) async {
    final db = await database;
    final maps = await db.query(
      'entry',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'entry_date DESC',
      limit: limit,
    );

    return maps.map((map) => EntryModel.fromMap(map)).toList();
  }

  Future<void> updateEntry(EntryModel entry) async {
    final db = await database;
    await db.update(
      'entry',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> updateEntryStatus(int entryId, String status) async {
    final db = await database;
    await db.update(
      'entry',
      {'status': status},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  // Archive Operations
  Future<void> archiveCurrentHabit() async {
    final db = await database;
    final habit = await getCurrentHabit();
    if (habit == null) return;

    final archiveHabit = ArchiveHabitModel(
      title: habit.title,
      reason: habit.reason,
      tone: habit.tone,
      startedAt: habit.startedAt,
      endedAt: DateTime.now(),
      finalStreak: habit.currentStreak,
    );

    final archiveHabitId = await db.insert('archive_habit', archiveHabit.toMap());

    // Copy all entries to archive
    final entries = await db.query('entry', where: 'habit_id = ?', whereArgs: [habit.id]);
    for (final entryMap in entries) {
      final archiveEntry = {
        'archive_habit_id': archiveHabitId,
        'entry_date': entryMap['entry_date'],
        'status': entryMap['status'],
        'roast_screen': entryMap['roast_screen'],
        'roast_done': entryMap['roast_done'],
        'roast_missed': entryMap['roast_missed'],
      };
      await db.insert('archive_entry', archiveEntry);
    }

    // Delete current habit and entries
    await db.delete('entry', where: 'habit_id = ?', whereArgs: [habit.id]);
    await db.delete('habit', where: 'id = ?', whereArgs: [habit.id]);
  }

  Future<List<ArchiveHabitModel>> getArchivedHabits() async {
    final db = await database;
    final maps = await db.query('archive_habit', orderBy: 'ended_at DESC');
    return maps.map((map) => ArchiveHabitModel.fromMap(map)).toList();
  }

  // Utility Methods
  Future<int> calculateCurrentStreak(int habitId) async {
    final db = await database;
    final maps = await db.query(
      'entry',
      where: 'habit_id = ? AND status = "done"',
      whereArgs: [habitId],
      orderBy: 'entry_date DESC',
    );

    if (maps.isEmpty) return 0;

    int streak = 0;
    DateTime? lastDate;

    for (final map in maps) {
      final entryDate = DateTime.fromMillisecondsSinceEpoch(map['entry_date'] as int);
      final dayOnly = DateTime(entryDate.year, entryDate.month, entryDate.day);

      if (lastDate == null) {
        lastDate = dayOnly;
        streak = 1;
      } else {
        final expectedPrevious = lastDate.subtract(const Duration(days: 1));
        if (dayOnly == expectedPrevious) {
          streak++;
          lastDate = dayOnly;
        } else {
          break;
        }
      }
    }

    return streak;
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('entry');
    await db.delete('habit');
    await db.delete('archive_entry');
    await db.delete('archive_habit');
  }
}