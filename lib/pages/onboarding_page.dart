import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit_model.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../widgets/roast_loading_dialog.dart';
import 'main_tracker_page.dart';
import '../services/notification_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  String _selectedHabit = '';
  String _customHabit = '';
  final TextEditingController _reasonController = TextEditingController();
  String _selectedTone = 'mild';
  // Notification step state
  bool _notificationsEnabled = true;
  TimeOfDay _reminderTime = TimeOfDay(hour: 8, minute: 0);

  final List<Map<String, String>> _habitOptions = [
    {'emoji': '🏋️', 'title': 'Gym', 'value': 'gym'},
    {'emoji': '🍭🚫', 'title': 'No Sugar', 'value': 'no_sugar'},
    {'emoji': '📚', 'title': 'Reading', 'value': 'reading'},
    {'emoji': '🧘', 'title': 'Meditation', 'value': 'meditation'},
    {'emoji': '💧', 'title': 'Water', 'value': 'water'},
    {'emoji': '🛌', 'title': 'Sleep 11 PM', 'value': 'sleep'},
  ];

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() {
      setState(() {});
    });
    // Set defaults for notification step
    NotificationService().areNotificationsEnabled().then((enabled) {
      setState(() => _notificationsEnabled = enabled);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      if (_currentStep > 1) {
        // Navigate to the next page in the PageView
        // PageView page index = _currentStep - 1 (since step 0 is welcome, step 1 is page 0)
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _completeOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      if (_currentStep >= 1) {
        // Navigate to the previous page in the PageView
        // PageView page index = _currentStep - 1 (since step 0 is welcome, step 1 is page 0)  
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final habitTitle = _selectedHabit == 'other' ? _customHabit : _selectedHabit;
    final reason = _reasonController.text.trim();

    if (habitTitle.isEmpty || reason.isEmpty) return;

    // Create step notifier for progressive loading
    final stepNotifier = ValueNotifier<int>(0);

    // Show loading dialog
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => RoastLoadingDialog(stepNotifier: stepNotifier),
    );

    try {
      // Format reminder time if notifications are enabled
      String? reminderTimeString;
      if (_notificationsEnabled) {
        reminderTimeString = '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';
      }

      // Create habit
      final habit = HabitModel(
        title: habitTitle,
        reason: reason,
        tone: _selectedTone,
        startedAt: DateTime.now(),
        reminderTime: reminderTimeString,  // Add reminder time
      );

      final habitId = await DatabaseService().insertHabit(habit);
      
      // Step 1: Move to roast generation
      stepNotifier.value = 1;
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay for UX

      // Set notification preferences
      await NotificationService().setNotificationsEnabled(_notificationsEnabled);

      // Generate initial roasts
      final supabaseService = SupabaseService();
      final roasts = await supabaseService.generateRoasts(
        habit: habitTitle,
        reason: reason,
        tone: _selectedTone,
        streak: 0,
        consecutiveMisses: 0,
        escalationState: 0,
        count: 7,
      );
      
      // Step 2: Move to notifications setup
      stepNotifier.value = 2;
      await Future.delayed(const Duration(milliseconds: 500));

      // Create entries for the next 7 days
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final entryDate = now.add(Duration(days: i));
        final roast = roasts[i % roasts.length];
        
        final entry = EntryModel(
          habitId: habitId,
          entryDate: entryDate,
          status: i == 0 ? 'pending' : 'future',
          roastScreen: roast.screen,
          roastDone: roast.done,
          roastMissed: roast.missed,
        );

        await DatabaseService().insertEntry(entry);
      }

      // Schedule notifications if enabled
      if (_notificationsEnabled && reminderTimeString != null) {
        final todayRoast = roasts[0];
        await NotificationService().scheduleHabitReminders(
          habit.copyWith(id: habitId),
          todayRoast.screen,
          todayRoast.missed,
        );
      }
      
      // Step 3: Final step
      stepNotifier.value = 3;
      await Future.delayed(const Duration(milliseconds: 800)); // Longer delay for final step

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(); // Close loading dialog
        }
        stepNotifier.dispose(); // Clean up notifier
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainTrackerPage()),
              (route) => false,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(); // Close loading dialog
        }
        stepNotifier.dispose(); // Clean up notifier
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create habit: \$e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator (hidden on welcome screen)
            if (_currentStep > 0)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: index <= (_currentStep - 1)
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            
            // Page content
            Expanded(
              child: _currentStep == 0 
                ? _buildWelcomeStep()
                : PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildHabitSelectionStep(),
                      _buildReasonStep(),
                      _buildToneStep(),
                      _buildNotificationStep(),
                    ],
                  ),
            ),
            
            // Navigation buttons (hidden on welcome screen)
            if (_currentStep > 0)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_currentStep == 4) ...[
                      ElevatedButton(
                        onPressed: () {
                          Superwall.shared.registerPlacement(
                            'onboarding_generate_roosts',
                            feature: () {
                              _completeOnboarding();
                            },
                          );
                        },
                        style: _whiteButtonStyle,
                        child: const Text('Save & Continue'),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Superwall.shared.registerPlacement(
                              'onboarding_generate_roosts',
                              feature: () {
                                _completeOnboarding();
                              },
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                          ),
                          child: const Text('Skip'),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _canProceed() ? _nextStep : null,
                        style: _whiteButtonStyle,
                        child: Text(_currentStep == 3 ? 'Next' : 'Next'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(String title) {
    return Row(
      children: [
        if (_currentStep > 0)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: _prevStep,
            tooltip: 'Back',
          ),
        if (_currentStep > 0) const SizedBox(width: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          
          // Welcome app icon
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.asset(
                'assets/icons/Icon-512.png',
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Title
          Text(
            'Welcome to Roasty',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 32,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            'Get brutally roasted to build that one habit you keep avoiding! 🔥',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF9E9E9E),
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          
          const Spacer(),
          
          // Let's go button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A2BE2),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                elevation: 2,
                shadowColor: Colors.black12,
              ),
              child: const Text('Let\'s Go 😈'),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHabitSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('Choose Your Habit'),
          const SizedBox(height: 8),
          Text(
            'Pick one habit to focus on. You can only track one at a time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 32),
          
          // Habit cards
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: _habitOptions.length + 1,
              itemBuilder: (context, index) {
                if (index == _habitOptions.length) {
                  return _buildOtherHabitCard();
                }
                
                final habit = _habitOptions[index];
                final isSelected = _selectedHabit == habit['value'];
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedHabit = habit['value']!),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : const Color(0xFF111111),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF222222),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          habit['emoji']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          habit['title']!,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherHabitCard() {
    final isSelected = _selectedHabit == 'other';
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedHabit = 'other');
        _showCustomHabitDialog();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : const Color(0xFF111111),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFF222222),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'Other...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (isSelected && _customHabit.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _customHabit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCustomHabitDialog() {
    final controller = TextEditingController(text: _customHabit);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Custom Habit'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your habit...',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _customHabit = controller.text.trim());
              Navigator.pop(context);
            },
            style: _whiteButtonStyle,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonStep() {
    final List<String> suggestions = [
      'To get healthier',
      'To build discipline',
      'To feel more energetic',
      'To prove I can do it',
    ];
    final selectedIndex = suggestions.indexWhere((s) => s == _reasonController.text.trim());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('Why This Habit?'),
          const SizedBox(height: 8),
          Text(
            'Tell us why this habit matters to you. This helps personalize your roasts.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 32),

          // Suggestions as a vertical column
          Column(
            children: List.generate(suggestions.length, (i) {
              final isSelected = selectedIndex == i;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    _reasonController.text = suggestions[i];
                    _reasonController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _reasonController.text.length),
                    );
                    setState(() {});
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                          : const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      child: Row(
                        children: [
                          if (isSelected)
                            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                          else
                            Icon(Icons.circle_outlined, color: const Color(0xFF444444)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              suggestions[i],
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Text field for custom reason
          TextField(
            controller: _reasonController,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Why is this important to you?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF222222)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFF111111),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToneStep() {
    const toneOptions = [
      {'value': 'motivational', 'label': 'Motivational', 'icon': '💪', 'desc': 'Encouraging and supportive'},
      {'value': 'mild', 'label': 'Mild', 'icon': '😊', 'desc': 'Gentle teasing and humor'},
      {'value': 'medium', 'label': 'Medium', 'icon': '😏', 'desc': 'Sharp wit and sarcasm'},
      {'value': 'brutal', 'label': 'Brutal', 'icon': '😈', 'desc': 'Savage roasts and dark humor'},
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('Choose Your Tone'),
          const SizedBox(height: 8),
          Text(
            'How would you like to be motivated? You can change this later.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 32),
          
          Expanded(
            child: ListView.builder(
              itemCount: toneOptions.length,
              itemBuilder: (context, index) {
                final option = toneOptions[index];
                final isSelected = _selectedTone == option['value'];
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedTone = option['value']!),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : const Color(0xFF111111),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF222222),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Text(
                          option['icon']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option['label']!,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                option['desc']!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('Set Up Notifications'),
          const SizedBox(height: 8),
          Text(
            'Get daily reminders and control how you want to be notified. You can change these settings later.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF222222)),
            ),
            child: SwitchListTile(
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val),
              title: const Text('Enable Notifications', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Get daily reminders for your habit', style: TextStyle(color: Color(0xFF9E9E9E))),
              activeColor: const Color(0xFF8A2BE2),
              inactiveThumbColor: const Color(0xFF666666),
              inactiveTrackColor: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF222222)),
            ),
            child: ListTile(
              leading: const Icon(Icons.schedule, color: Color(0xFF8A2BE2)),
              title: const Text('Reminder Time', style: TextStyle(color: Colors.white)),
              subtitle: Text(_reminderTime.format(context), style: const TextStyle(color: Color(0xFF9E9E9E))),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        timePickerTheme: const TimePickerThemeData(
                          backgroundColor: Color(0xFF111111),
                          hourMinuteTextColor: Colors.white,
                          dayPeriodTextColor: Colors.white,
                          dialHandColor: Color(0xFF8A2BE2),
                          dialTextColor: Colors.white,
                          dialBackgroundColor: Color(0xFF222222),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _reminderTime = picked);
                }
              },
            ),
          ),
          const Spacer(),
          Center(
            child: Text(
              'You can always change these in Settings.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF9E9E9E)),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return true; // Welcome screen always allows proceed
      case 1:
        return _selectedHabit.isNotEmpty && 
               (_selectedHabit != 'other' || _customHabit.isNotEmpty);
      case 2:
        return _reasonController.text.trim().isNotEmpty;
      case 3:
        return _selectedTone.isNotEmpty;
      case 4:
        return true;
      default:
        return false;
    }
  }

  ButtonStyle get _whiteButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 2,
        shadowColor: Colors.black12,
      );
  ButtonStyle get _whiteOutlinedButtonStyle => OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        side: const BorderSide(color: Colors.white, width: 2),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      );
}