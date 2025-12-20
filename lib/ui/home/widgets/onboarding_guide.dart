import 'package:flutter/material.dart';
import 'package:little_star_app/data/services/onboarding_service.dart';

/// Onboarding guide overlay widget
class OnboardingGuide extends StatefulWidget {
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onComplete;

  const OnboardingGuide({
    super.key,
    required this.currentStep,
    required this.onNext,
    required this.onSkip,
    required this.onComplete,
  });

  @override
  State<OnboardingGuide> createState() => _OnboardingGuideState();
}

class _OnboardingGuideState extends State<OnboardingGuide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = OnboardingStep.defaultSteps[widget.currentStep];
    final theme = Theme.of(context);
    final isLastStep = widget.currentStep >= OnboardingStep.defaultSteps.length - 1;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withValues(alpha: 0.7),
        child: SafeArea(
          child: Stack(
            children: [
              // Tap to dismiss (only on overlay background)
              Positioned.fill(
                child: GestureDetector(
                  onTap: widget.onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

              // Content card
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GestureDetector(
                    onTap: () {}, // Prevent tap through
                    child: Card(
                      elevation: 8,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Step indicator
                            _buildStepIndicator(theme),
                            const SizedBox(height: 24),

                            // Icon
                            _buildIcon(widget.currentStep, theme),
                            const SizedBox(height: 16),

                            // Title
                            Text(
                              step.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),

                            // Description
                            Text(
                              step.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: widget.onSkip,
                                  child: const Text('Skip'),
                                ),
                                FilledButton(
                                  onPressed: isLastStep ? widget.onComplete : widget.onNext,
                                  child: Text(isLastStep ? 'Get Started' : 'Next'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        OnboardingStep.defaultSteps.length,
        (index) {
          final isActive = index == widget.currentStep;
          final isCompleted = index < widget.currentStep;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? theme.colorScheme.primary
                  : isCompleted
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : Colors.grey[300],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIcon(int step, ThemeData theme) {
    IconData icon;
    Color color;

    switch (step) {
      case 0:
        icon = Icons.waving_hand;
        color = Colors.orange;
        break;
      case 1:
        icon = Icons.download;
        color = Colors.blue;
        break;
      case 2:
        icon = Icons.auto_awesome;
        color = Colors.purple;
        break;
      case 3:
        icon = Icons.folder;
        color = Colors.green;
        break;
      default:
        icon = Icons.info;
        color = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 48,
        color: color,
      ),
    );
  }
}
