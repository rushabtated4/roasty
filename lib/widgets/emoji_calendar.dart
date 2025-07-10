import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/habit_model.dart';

class EmojiCalendar extends StatefulWidget {
  final List<EntryModel> entries;
  final Function(DateTime)? onMonthChanged;

  const EmojiCalendar({
    super.key,
    required this.entries,
    this.onMonthChanged,
  });

  @override
  State<EmojiCalendar> createState() => _EmojiCalendarState();
}

class _EmojiCalendarState extends State<EmojiCalendar> {
  late DateTime _currentMonth;
  static const int _initialPage = 1200; // Represents 100 years of months
  final PageController _pageController = PageController(initialPage: _initialPage);

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getEmojiForDate(DateTime date) {
    final today = DateTime.now();
    final dayOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);

    // Find entry for this date
    final entry = widget.entries.firstWhere(
      (e) {
        final entryDay = DateTime(e.entryDate.year, e.entryDate.month, e.entryDate.day);
        return entryDay == dayOnly;
      },
      orElse: () => EntryModel(habitId: -1, entryDate: date),
    );

    if (entry.habitId == -1) {
      // No entry found
      return '';
    }

    switch (entry.status) {
      case 'done':
        return '😈';
      case 'missed':
        return '😭';
      case 'pending':
        return dayOnly.isAfter(todayOnly) ? '' : '😢';
      default:
        return '';
    }
  }

  List<DateTime> _getCalendarDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    
    // Start from Monday
    final startDate = firstDay.subtract(Duration(days: (firstDay.weekday - 1) % 7));
    final endDate = lastDay.add(Duration(days: (7 - lastDay.weekday) % 7));
    
    final days = <DateTime>[];
    for (DateTime date = startDate; date.isBefore(endDate.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      days.add(date);
    }
    
    return days;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate a fixed height for the calendar to prevent layout jumps
    final screenWidth = MediaQuery.of(context).size.width;
    final calendarPadding = 16.0 * 2; // Corresponds to main page padding
    final dayCellWidth = (screenWidth - calendarPadding) / 7;
    final calendarHeight = dayCellWidth * 6; // Assume max 6 rows for a month

    return Column(
      children: [
        // Days of week header
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF9E9E9E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 8),
        
        // Calendar grid with swipe functionality
        SizedBox(
          height: calendarHeight,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              final newMonth = DateTime(DateTime.now().year, DateTime.now().month + (page - _initialPage));
              setState(() => _currentMonth = newMonth);
              widget.onMonthChanged?.call(newMonth);
            },
            itemBuilder: (context, index) {
              final month = DateTime(DateTime.now().year, DateTime.now().month + (index - _initialPage));
              return _buildCalendarGrid(month);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(DateTime month) {
    final days = _getCalendarDays(month);
    final rows = <Widget>[];
    
    for (int i = 0; i < days.length; i += 7) {
      final weekDays = days.sublist(i, i + 7);
      rows.add(
        Row(
          children: weekDays.map((day) => _buildCalendarCell(day, month)).toList(),
        ),
      );
    }
    
    return Column(
      key: ValueKey(month.month),
      children: rows,
    );
  }

  Widget _buildCalendarCell(DateTime date, DateTime currentDisplayMonth) {
    final isCurrentMonth = date.month == currentDisplayMonth.month;
    final isToday = _isToday(date);
    final emoji = _getEmojiForDate(date);
    
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isCurrentMonth
                ? (isToday ? const Color(0xFF00D07E).withOpacity(0.1) : const Color(0xFF222222))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: const Color(0xFF00D07E), width: 2)
                : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                emoji,
                key: ValueKey('\${date.day}-\$emoji'),
                style: TextStyle(
                  fontSize: 20,
                  color: isCurrentMonth ? null : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }
}