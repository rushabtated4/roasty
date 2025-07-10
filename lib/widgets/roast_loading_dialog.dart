import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide RadialGradient;
import 'dart:math' as math;

class RoastLoadingDialog extends StatefulWidget {
  final ValueNotifier<int>? stepNotifier;
  const RoastLoadingDialog({super.key, this.stepNotifier});

  @override
  State<RoastLoadingDialog> createState() => _RoastLoadingDialogState();
}

class _RoastLoadingDialogState extends State<RoastLoadingDialog>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  int _currentStep = 0;
  
  final List<Map<String, String>> _loadingSteps = [
    {
      'title': 'Creating your habit...',
      'subtitle': 'Setting up your personal tracking',
      'emoji': '⚡'
    },
    {
      'title': 'Cooking up savage roasts...',
      'subtitle': 'Generating personalized motivation',
      'emoji': '🔥'
    },
    {
      'title': 'Setting up notifications...',
      'subtitle': 'Preparing your daily reminders',
      'emoji': '📱'
    },
    {
      'title': 'Almost ready!',
      'subtitle': 'Finalizing your roast experience',
      'emoji': '😈'
    },
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Listen to step changes
    widget.stepNotifier?.addListener(_onStepChanged);
  }
  
  void _onStepChanged() {
    if (mounted && widget.stepNotifier != null) {
      setState(() {
        _currentStep = widget.stepNotifier!.value.clamp(0, _loadingSteps.length - 1);
      });
    }
  }

  @override
  void dispose() {
    widget.stepNotifier?.removeListener(_onStepChanged);
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStepData = _loadingSteps[_currentStep];
    
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEnhancedAnimation(),
            const SizedBox(height: 40),
            
            // Main title with step emoji
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentStepData['emoji']!,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    currentStepData['title']!,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Subtitle
            Text(
              currentStepData['subtitle']!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF9E9E9E),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Progress indicator
            _buildProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedAnimation() {
    return AnimatedBuilder(
      animation: Listenable.merge([_progressController, _pulseController]),
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFF00D07E).withOpacity(0.4 + 0.2 * _pulseController.value),
                const Color(0xFF00D07E).withOpacity(0.2),
                const Color(0xFFFF3B30).withOpacity(0.1),
                Colors.transparent,
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulsing ring
                Transform.scale(
                  scale: 1.0 + (0.3 * _pulseController.value),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00D07E).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Main flame icon with breathing effect
                Transform.scale(
                  scale: 1.0 + (0.15 * (1.0 + _progressController.value.sin())),
                  child: const Icon(
                    Icons.whatshot,
                    size: 50,
                    color: Color(0xFF00D07E),
                  ),
                ),
                // Rotating sparkles
                Transform.rotate(
                  angle: _progressController.value * 6.28,
                  child: Stack(
                    children: [
                      Positioned(
                        top: -30,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: const Color(0xFFFF3B30).withOpacity(0.8),
                        ),
                      ),
                      Positioned(
                        bottom: -30,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: const Color(0xFF00D07E).withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        // Progress dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_loadingSteps.length, (index) {
            final isActive = index <= _currentStep;
            final isCurrent = index == _currentStep;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isCurrent ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive 
                    ? const Color(0xFF00D07E)
                    : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        // Step counter
        Text(
          'Step ${_currentStep + 1} of ${_loadingSteps.length}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF666666),
          ),
        ),
      ],
    );
  }
}

// Extension to add sin function to double
extension on double {
  double sin() => math.sin(this * math.pi);
}