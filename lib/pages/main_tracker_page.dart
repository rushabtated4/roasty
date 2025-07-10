import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit_model.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../widgets/emoji_calendar.dart';
import '../widgets/roast_loading_dialog.dart';
import '../widgets/superwall_paywall.dart';
import 'settings_page.dart';
import 'onboarding_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:async';

// Providers
final habitProvider = StateNotifierProvider<HabitNotifier, HabitModel?>((ref) {
  return HabitNotifier();
});

final entriesProvider = StateNotifierProvider<EntriesNotifier, List<EntryModel>>((ref) {
  return EntriesNotifier();
});

class HabitNotifier extends StateNotifier<HabitModel?> {
  HabitNotifier() : super(null) {
    _loadHabit();
  }

  Future<void> _loadHabit() async {
    final habit = await DatabaseService().getCurrentHabit();
    state = habit;
  }

  void updateHabit(HabitModel habit) {
    state = habit;
  }
}

class EntriesNotifier extends StateNotifier<List<EntryModel>> {
  EntriesNotifier() : super([]);

  Future<void> loadEntriesForMonth(int habitId, DateTime month) async {
    final entries = await DatabaseService().getEntriesForMonth(habitId, month);
    state = entries;
  }

  void addEntry(EntryModel entry) {
    state = [...state, entry];
  }

  void updateEntry(EntryModel updatedEntry) {
    state = state.map((entry) {
      return entry.id == updatedEntry.id ? updatedEntry : entry;
    }).toList();
  }
}

class MainTrackerPage extends ConsumerStatefulWidget {
  const MainTrackerPage({super.key});

  @override
  ConsumerState<MainTrackerPage> createState() => _MainTrackerPageState();
}

class _MainTrackerPageState extends ConsumerState<MainTrackerPage> {
  EntryModel? _todayEntry;
  DateTime _currentMonth = DateTime.now();
  String? _lastAction; // Track last action: 'done' or 'missed'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final habit = await DatabaseService().getCurrentHabit();
    if (habit == null) {
      // No habit found, redirect to onboarding
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const OnboardingPage()),
            );
          }
        });
      }
      return;
    }

    ref.read(habitProvider.notifier).updateHabit(habit);
    
    // Load today's entry
    final todayEntry = await DatabaseService().getTodayEntry(habit.id!);
    debugPrint('[DEBUG] _loadData: todayEntry = '
      '${todayEntry != null ? todayEntry.entryDate.toIso8601String() : 'null'}, '
      'status = ${todayEntry != null ? todayEntry.status : 'null'}');

    // If today's entry is 'future', update it to 'pending'
    if (todayEntry != null && todayEntry.status == 'future') {
      debugPrint('[DEBUG] _loadData: Fixing status from future to pending for today\'s entry');
      await DatabaseService().updateEntryStatus(todayEntry.id!, 'pending');
      final fixedEntry = todayEntry.copyWith(status: 'pending');
      setState(() => _todayEntry = fixedEntry);
    } else {
      setState(() => _todayEntry = todayEntry);
    }

    // Load calendar entries
    await ref.read(entriesProvider.notifier).loadEntriesForMonth(habit.id!, _currentMonth);
    
    // Create today's entry if it doesn't exist
    if (todayEntry == null) {
      debugPrint('[DEBUG] _loadData: Creating new entry for today');
      await _createTodayEntry(habit);
    }
  }

  Future<void> _createTodayEntry(HabitModel habit) async {
    // Get cached roast or create dummy one
    final recentEntries = await DatabaseService().getRecentEntries(habit.id!, 1);
    final roastScreen = recentEntries.isNotEmpty 
        ? recentEntries.first.roastScreen 
        : 'Time to make today count!';

    final entry = EntryModel(
      habitId: habit.id!,
      entryDate: DateTime.now(),
      status: 'pending',
      roastScreen: roastScreen,
      roastDone: 'Great work! Keep it up!',
      roastMissed: 'Tomorrow is a fresh start.',
    );

    final entryId = await DatabaseService().insertEntry(entry);
    debugPrint('[DEBUG] _createTodayEntry: Created entry for today with id = $entryId, date = '
      '${entry.entryDate.toIso8601String()}, status = pending');
    
    final newEntry = entry.copyWith(id: entryId);
    setState(() {
      _todayEntry = newEntry;
    });

    // Schedule notifications with today's messages
    if (habit.reminderTime != null) {
      await NotificationService().scheduleHabitReminders(
        habit,
        newEntry.roastScreen,
        newEntry.roastMissed,
      );
    }
  }

  Future<void> _markHabitStatus(String status) async {
    if (_todayEntry == null) return;

    // Update entry status
    await DatabaseService().updateEntryStatus(_todayEntry!.id!, status);
    
    // Cancel missed notification if marked as done
    if (status == 'done') {
      await NotificationService().cancelNotification(2);
    }
    
    // Update local state
    setState(() {
      _todayEntry = _todayEntry!.copyWith(status: status);
      _lastAction = status;
    });

    // Update habit streak
    final habit = ref.read(habitProvider);
    if (habit != null) {
      final newStreak = await DatabaseService().calculateCurrentStreak(habit.id!);
      final updatedHabit = habit.copyWith(currentStreak: newStreak);
      await DatabaseService().updateHabit(updatedHabit);
      ref.read(habitProvider.notifier).updateHabit(updatedHabit);
    }

    // Refresh calendar
    if (habit != null) {
      await ref.read(entriesProvider.notifier).loadEntriesForMonth(habit.id!, _currentMonth);
    }

    // Generate new roasts
    await _generateNewRoasts();

    // Show success toast
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'done' ? 'Habit completed! 🔥' : 'Marked as missed'),
          backgroundColor: status == 'done' 
              ? const Color(0xFF00D07E) 
              : const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _generateNewRoasts() async {
    final habit = ref.read(habitProvider);
    if (habit == null) return;

    try {
      final supabaseService = SupabaseService();
      final roasts = await supabaseService.generateRoasts(
        habit: habit.title,
        reason: habit.reason,
        tone: habit.tone,
        streak: habit.currentStreak,
        consecutiveMisses: habit.consecutiveMisses,
        escalationState: habit.escalationState,
        count: 7,
      );

      // Store roasts for future days
      final now = DateTime.now();
      for (int i = 1; i <= 7; i++) {
        final futureDate = now.add(Duration(days: i));
        final roast = roasts[(i - 1) % roasts.length];
        
        final entry = EntryModel(
          habitId: habit.id!,
          entryDate: futureDate,
          status: 'future',
          roastScreen: roast.screen,
          roastDone: roast.done,
          roastMissed: roast.missed,
        );

        await DatabaseService().insertEntry(entry);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate roasts: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showSchedulePaywall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SuperwallPaywall(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habit = ref.watch(habitProvider);
    final entries = ref.watch(entriesProvider);

    if (habit == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00D07E))),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top section: streak header and menu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: _buildStreakHeader(habit)),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    },
                    icon: const Icon(Icons.menu, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Message area (auto-size)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: (_todayEntry == null || _todayEntry!.status == 'pending')
                      ? AutoSizeText(
                          _todayEntry?.roastScreen ?? 'Ready to make today count?',
                          style: GoogleFonts.fredoka(
                            fontSize: 42,
                            color: Colors.white,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              const Shadow(
                                blurRadius: 10.0,
                                color: Colors.black54,
                                offset: Offset(2.0, 2.0),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.left,
                          maxLines: 5,
                          minFontSize: 20,
                        )
                      : AutoSizeText(
                          _todayEntry!.status == 'done'
                              ? _todayEntry!.roastDone
                              : _todayEntry!.roastMissed,
                          style: GoogleFonts.fredoka(
                            fontSize: 54,
                            color: _todayEntry!.status == 'done'
                                ? const Color(0xFF00D07E)
                                : const Color(0xFFFF3B30),
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              const Shadow(
                                blurRadius: 10.0,
                                color: Colors.black54,
                                offset: Offset(2.0, 2.0),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.left,
                          maxLines: 6,
                          minFontSize: 18,
                        ),
                ),
              ),
            ),
            // Bottom section: calendar and buttons
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    EmojiCalendar(
                      entries: entries,
                      onMonthChanged: (month) async {
                        setState(() => _currentMonth = month);
                        await ref.read(entriesProvider.notifier).loadEntriesForMonth(habit.id!, month);
                      },
                    ),
                    const SizedBox(height: 32),
                    if (_todayEntry?.status == 'pending') ...[
                      _buildActionButtons(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakHeader(HabitModel habit) {
    final streakEmoji = habit.currentStreak == 0 ? '🥵' : '🔥';
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          streakEmoji,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(width: 8),
        Text(
          '${habit.currentStreak}',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: const Color(0xFF00D07E),
            fontWeight: FontWeight.w900,
            fontSize: 48,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Day Streak',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => _markHabitStatus('done'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          child: Text(
            'Mark as Done',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _markHabitStatus('missed'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Skipped today',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFFF3B30),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}