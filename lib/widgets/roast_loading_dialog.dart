import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide RadialGradient;
import 'dart:math' as math;

class RoastLoadingDialog extends StatefulWidget {
  const RoastLoadingDialog({super.key});

  @override
  State<RoastLoadingDialog> createState() => _RoastLoadingDialogState();
}

class _RoastLoadingDialogState extends State<RoastLoadingDialog>
    with TickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFlameAnimation(),
            const SizedBox(height: 32),
            Text(
              'Sharpening roasts...',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This might take a few seconds',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlameAnimation() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFF00D07E).withOpacity(0.3),
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
                // Animated flame icon
                Transform.scale(
                  scale: 1.0 + (0.2 * (1.0 + _progressController.value.sin())),
                  child: const Icon(
                    Icons.whatshot,
                    size: 40,
                    color: Color(0xFF00D07E),
                  ),
                ),
                // Animated hammer effect
                Transform.rotate(
                  angle: _progressController.value * 6.28 * 2, // 2 full rotations
                  child: const Icon(
                    Icons.build,
                    size: 20,
                    color: Color(0xFFFF3B30),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Extension to add sin function to double
extension on double {
  double sin() => math.sin(this * math.pi);
}