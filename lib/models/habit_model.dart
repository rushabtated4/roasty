class HabitModel {
  final int? id;
  final String title;
  final String reason;
  final String tone;
  final String plan;
  final DateTime startedAt;
  final String? reminderTime;
  final int currentStreak;
  final int consecutiveMisses;
  final int escalationState;

  HabitModel({
    this.id,
    required this.title,
    required this.reason,
    required this.tone,
    this.plan = 'free',
    required this.startedAt,
    this.reminderTime,
    this.currentStreak = 0,
    this.consecutiveMisses = 0,
    this.escalationState = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'reason': reason,
      'tone': tone,
      'plan': plan,
      'started_at': startedAt.millisecondsSinceEpoch,
      'reminder_time': reminderTime,
      'current_streak': currentStreak,
      'consecutive_misses': consecutiveMisses,
      'escalation_state': escalationState,
    };
  }

  factory HabitModel.fromMap(Map<String, dynamic> map) {
    return HabitModel(
      id: map['id'],
      title: map['title'],
      reason: map['reason'],
      tone: map['tone'],
      plan: map['plan'] ?? 'free',
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at']),
      reminderTime: map['reminder_time'],
      currentStreak: map['current_streak'] ?? 0,
      consecutiveMisses: map['consecutive_misses'] ?? 0,
      escalationState: map['escalation_state'] ?? 0,
    );
  }

  HabitModel copyWith({
    int? id,
    String? title,
    String? reason,
    String? tone,
    String? plan,
    DateTime? startedAt,
    String? reminderTime,
    int? currentStreak,
    int? consecutiveMisses,
    int? escalationState,
  }) {
    return HabitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      reason: reason ?? this.reason,
      tone: tone ?? this.tone,
      plan: plan ?? this.plan,
      startedAt: startedAt ?? this.startedAt,
      reminderTime: reminderTime ?? this.reminderTime,
      currentStreak: currentStreak ?? this.currentStreak,
      consecutiveMisses: consecutiveMisses ?? this.consecutiveMisses,
      escalationState: escalationState ?? this.escalationState,
    );
  }
}

class EntryModel {
  final int? id;
  final int habitId;
  final DateTime entryDate;
  final String status; // 'pending', 'done', 'missed'
  final String roastScreen;
  final String roastDone;
  final String roastMissed;

  EntryModel({
    this.id,
    required this.habitId,
    required this.entryDate,
    this.status = 'pending',
    this.roastScreen = '',
    this.roastDone = '',
    this.roastMissed = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'entry_date': entryDate.millisecondsSinceEpoch,
      'status': status,
      'roast_screen': roastScreen,
      'roast_done': roastDone,
      'roast_missed': roastMissed,
    };
  }

  factory EntryModel.fromMap(Map<String, dynamic> map) {
    return EntryModel(
      id: map['id'],
      habitId: map['habit_id'],
      entryDate: DateTime.fromMillisecondsSinceEpoch(map['entry_date']),
      status: map['status'] ?? 'pending',
      roastScreen: map['roast_screen'] ?? '',
      roastDone: map['roast_done'] ?? '',
      roastMissed: map['roast_missed'] ?? '',
    );
  }

  EntryModel copyWith({
    int? id,
    int? habitId,
    DateTime? entryDate,
    String? status,
    String? roastScreen,
    String? roastDone,
    String? roastMissed,
  }) {
    return EntryModel(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      entryDate: entryDate ?? this.entryDate,
      status: status ?? this.status,
      roastScreen: roastScreen ?? this.roastScreen,
      roastDone: roastDone ?? this.roastDone,
      roastMissed: roastMissed ?? this.roastMissed,
    );
  }
}

class ArchiveHabitModel {
  final int? id;
  final String title;
  final String reason;
  final String tone;
  final DateTime startedAt;
  final DateTime endedAt;
  final int finalStreak;

  ArchiveHabitModel({
    this.id,
    required this.title,
    required this.reason,
    required this.tone,
    required this.startedAt,
    required this.endedAt,
    required this.finalStreak,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'reason': reason,
      'tone': tone,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt.millisecondsSinceEpoch,
      'final_streak': finalStreak,
    };
  }

  factory ArchiveHabitModel.fromMap(Map<String, dynamic> map) {
    return ArchiveHabitModel(
      id: map['id'],
      title: map['title'],
      reason: map['reason'],
      tone: map['tone'],
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at']),
      endedAt: DateTime.fromMillisecondsSinceEpoch(map['ended_at']),
      finalStreak: map['final_streak'],
    );
  }
}

class RoastTriple {
  final String screen;
  final String done;
  final String missed;

  RoastTriple({
    required this.screen,
    required this.done,
    required this.missed,
  });

  factory RoastTriple.fromJson(Map<String, dynamic> json) {
    return RoastTriple(
      screen: json['screen'] ?? '',
      done: json['done'] ?? '',
      missed: json['missed'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'screen': screen,
      'done': done,
      'missed': missed,
    };
  }
}