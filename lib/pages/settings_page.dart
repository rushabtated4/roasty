import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/habit_model.dart';
import 'onboarding_page.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  HabitModel? _currentHabit;
  bool _notificationsEnabled = true;
  bool _roastsMuted = false;
  TimeOfDay _reminderTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final habit = await DatabaseService().getCurrentHabit();
    final notificationsEnabled = await NotificationService().areNotificationsEnabled();
    
    setState(() {
      _currentHabit = habit;
      _notificationsEnabled = notificationsEnabled;
      
      if (habit?.reminderTime != null) {
        final parts = habit!.reminderTime!.split(':');
        _reminderTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } else {
      }
    });
  }

  Future<void> _showTimePicker() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFF111111),
              hourMinuteTextColor: Colors.white,
              dayPeriodTextColor: Colors.white,
              dialHandColor: const Color(0xFF8A2BE2),
              dialTextColor: Colors.white,
              dialBackgroundColor: const Color(0xFF222222),
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null && _currentHabit != null) {
      final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      final updatedHabit = _currentHabit!.copyWith(reminderTime: timeString);
      await DatabaseService().updateHabit(updatedHabit);
      
      setState(() {
        _reminderTime = time;
        _currentHabit = updatedHabit;
      });

      // Reschedule notifications if enabled
      if (_notificationsEnabled) {
        // Get today's entry to fetch the roast and missed messages
        String roastText = 'Time for your habit!';
        String missedText = 'You missed your habit today!';
        if (updatedHabit.id != null) {
          final todayEntry = await DatabaseService().getTodayEntry(updatedHabit.id!);
          if (todayEntry != null) {
            if (todayEntry.roastScreen.isNotEmpty) {
              roastText = todayEntry.roastScreen;
            }
            if (todayEntry.roastMissed.isNotEmpty) {
              missedText = todayEntry.roastMissed;
            }
          }
        }
        try {
          await NotificationService().scheduleHabitReminders(
            updatedHabit,
            roastText,
            missedText,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Failed to schedule notifications: $e'),
                duration: const Duration(seconds: 5),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    await NotificationService().setNotificationsEnabled(enabled);
    setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _resetAndArchiveHabit() async {
    final confirmed = await _showResetConfirmationDialog();
    if (!confirmed) return;

    await DatabaseService().archiveCurrentHabit();
    await NotificationService().cancelAllNotifications();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const OnboardingPage()),
        (route) => false,
      );
    }
  }

  Future<bool> _showResetConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Reset & Archive Challenge'),
        content: const Text(
          'This will archive your current habit and start fresh. Your progress will be saved in history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
            ),
            child: const Text('Reset & Archive'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteAllData() async {
    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed) return;

    await DatabaseService().deleteAllData();
    await NotificationService().cancelAllNotifications();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const OnboardingPage()),
        (route) => false,
      );
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Delete All Data'),
        content: const Text(
          'This will permanently delete ALL your data including current habit, history, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    ) ?? false;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Reminders Section
          _buildSectionHeader('Reminders'),
          _buildSettingsTile(
            icon: Icons.schedule,
            title: 'Reminder Time',
            subtitle: _reminderTime.format(context),
            onTap: _showTimePicker,
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
          ),
          
          _buildSwitchTile(
            icon: Icons.notifications,
            title: 'Enable Notifications',
            subtitle: 'Get daily reminders for your habit',
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
          ),
          
          _buildSwitchTile(
            icon: Icons.volume_off,
            title: '24h Mute Roasts',
            subtitle: 'Replace roasts with neutral text until midnight',
            value: _roastsMuted,
            onChanged: (value) => setState(() => _roastsMuted = value),
          ),
          
          const SizedBox(height: 32),
          
          // Habit Control Section
          _buildSectionHeader('Habit Control'),
          _buildDangerTile(
            icon: Icons.archive,
            title: 'Reset & Archive Challenge',
            subtitle: 'Start fresh and save current progress to history',
            onTap: _resetAndArchiveHabit,
          ),
          
          _buildDangerTile(
            icon: Icons.delete_forever,
            title: 'Delete All Data',
            subtitle: 'Permanently delete all data and start over',
            onTap: _deleteAllData,
          ),
          
          const SizedBox(height: 32),
          
          // Support Section
          _buildSectionHeader('Support'),
          _buildSettingsTile(
            icon: Icons.help,
            title: 'Help / FAQ',
            subtitle: 'Get answers to common questions',
            onTap: () => _showBottomSheetWithContent(
              'Help / FAQ',
              '''Welcome to Roasty Help & FAQ!

- **How do I start a new habit?**
  Go to the onboarding screen and follow the steps to set up your habit, reason, tone, and notifications.

- **How do I mark a habit as done or missed?**
  On the main tracker page, tap "Mark as Done" or "Skipped today" to log your progress.

- **What are Roasty's roasts?**
  Roasty uses AI to generate personalized, witty, or motivational messages to keep you on track. If the internet is unavailable, fallback roasts are used.

- **How do I change my notification time?**
  Go to Settings > Reminders > Reminder Time and pick your preferred time.

- **How do I reset or delete my habit?**
  In Settings, use the Habit Control section to reset/archive or delete all data.

For more help, contact support from the Settings page.''',
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
          ),
          
          _buildSettingsTile(
            icon: Icons.email,
            title: 'Contact Support',
            subtitle: 'Get help from our team',
            onTap: () async {
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'rushab@audionotes.app',
                queryParameters: {
                  'subject': 'Roasty iOS Support',
                },
              );
              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open email app.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
          ),
          
          const SizedBox(height: 32),
          
          // Legal Section
          _buildSectionHeader('Legal'),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            onTap: () => _showBottomSheetWithContent(
              'Privacy Policy',
              '''Roasty Privacy Policy

- We value your privacy and do not sell your data.
- Your habit and progress data is stored securely on your device.
- Roasty uses OpenAI to generate roast messages, but does not share your personal information with third parties.
- You can delete all your data at any time from Settings.

For more details, contact support.''',
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
          ),
          
          _buildSettingsTile(
            icon: Icons.description,
            title: 'Terms & Conditions',
            subtitle: 'Our terms of service',
            onTap: () => _showBottomSheetWithContent(
              'Terms & Conditions',
              '''Roasty Terms & Conditions

- Roasty is a motivational habit tracker app that uses humor and AI-generated messages.
- By using Roasty, you agree to use the app for personal, non-commercial purposes.
- Roasty is not responsible for any emotional damage caused by savage roasts—remember, it's all in good fun!
- You may not reverse-engineer or redistribute the app without permission.

For questions, contact support.''',
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
          ),
          
          const SizedBox(height: 32),
          
          // App Info
          Center(
            child: Column(
              children: [
                Text(
                  'Roasty',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF8A2BE2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: const Color(0xFF8A2BE2),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF8A2BE2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF8A2BE2),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF9E9E9E),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF8A2BE2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF8A2BE2),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF9E9E9E),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF8A2BE2),
          inactiveThumbColor: const Color(0xFF666666),
          inactiveTrackColor: const Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFF3B30),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFFFF3B30),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF9E9E9E),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFFFF3B30),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showBottomSheetWithContent(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFormattedSheetContent(title),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedSheetContent(String title) {
    switch (title) {
      case 'Help / FAQ':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Getting Started'),
            _bullet('Start a new habit from the onboarding screen.'),
            _bullet('Follow the steps: habit, reason, tone, notifications.'),
            const SizedBox(height: 12),
            _sectionHeader('Tracking Progress'),
            _bullet('On the main tracker, tap "Mark as Done" or "Skipped today".'),
            _bullet('Your streak and calendar update automatically.'),
            const SizedBox(height: 12),
            _sectionHeader('Roasty Roasts'),
            _bullet('AI-generated, witty, or motivational messages.'),
            _bullet('Fallback roasts are used if offline.'),
            const SizedBox(height: 12),
            _sectionHeader('Notifications'),
            _bullet('Change your reminder time in Settings > Reminders.'),
            const SizedBox(height: 12),
            _sectionHeader('Reset or Delete'),
            _bullet('Reset/archive or delete all data in Settings > Habit Control.'),
            const SizedBox(height: 12),
            _sectionHeader('Need more help?'),
            Text('Contact support from the Settings page.', style: _sheetTextStyle()),
          ],
        );
      case 'Contact Support':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Contact Roasty Support'),
            _bullet('Email: support@roastyapp.com'),
            _bullet('Twitter: @roastyapp'),
            _bullet('In-app: Use this form to send us your questions or feedback.'),
            const SizedBox(height: 12),
            Text('Our team will get back to you as soon as possible!', style: _sheetTextStyle()),
          ],
        );
      case 'Privacy Policy':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Roasty Privacy Policy'),
            _bullet('We value your privacy and do not sell your data.'),
            _bullet('Your habit and progress data is stored securely on your device.'),
            _bullet('Roasty uses OpenAI to generate roast messages, but does not share your personal information with third parties.'),
            _bullet('You can delete all your data at any time from Settings.'),
            const SizedBox(height: 12),
            Text('For more details, contact support.', style: _sheetTextStyle()),
          ],
        );
      case 'Terms & Conditions':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Roasty Terms & Conditions'),
            _bullet('Roasty is a motivational habit tracker app that uses humor and AI-generated messages.'),
            _bullet('By using Roasty, you agree to use the app for personal, non-commercial purposes.'),
            _bullet('Roasty is not responsible for any emotional damage caused by savage roasts—remember, it\'s all in good fun!'),
            _bullet('You may not reverse-engineer or redistribute the app without permission.'),
            const SizedBox(height: 12),
            Text('For questions, contact support.', style: _sheetTextStyle()),
          ],
        );
      default:
        return Text('No details available.', style: _sheetTextStyle());
    }
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: const Color(0xFF8A2BE2),
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: Colors.white, fontSize: 16)),
        Expanded(child: Text(text, style: _sheetTextStyle())),
      ],
    ),
  );

  TextStyle _sheetTextStyle() => Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white);
}