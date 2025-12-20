import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing onboarding state and first-time user experience.
class OnboardingService {
  static const String _keyCompleted = 'onboarding_completed';
  static const String _keyCurrentStep = 'onboarding_current_step';
  static const int totalSteps = 4;

  final SharedPreferences _prefs;

  OnboardingService(this._prefs);

  /// Check if the user has completed the onboarding process
  Future<bool> hasCompleted() async {
    return _prefs.getBool(_keyCompleted) ?? false;
  }

  /// Get the current onboarding step (0-based index)
  Future<int> getCurrentStep() async {
    return _prefs.getInt(_keyCurrentStep) ?? 0;
  }

  /// Mark a specific step as completed
  Future<void> setStepCompleted(int step) async {
    await _prefs.setInt(_keyCurrentStep, step);

    // If this is the last step, mark onboarding as complete
    if (step >= totalSteps - 1) {
      await _prefs.setBool(_keyCompleted, true);
    }
  }

  /// Mark the entire onboarding as completed
  Future<void> setCompleted() async {
    await _prefs.setBool(_keyCompleted, true);
    await _prefs.setInt(_keyCurrentStep, totalSteps);
  }

  /// Skip the onboarding process
  Future<void> skip() async {
    await setCompleted();
  }

  /// Reset onboarding state (useful for debugging or settings)
  Future<void> reset() async {
    await _prefs.remove(_keyCompleted);
    await _prefs.remove(_keyCurrentStep);
  }

  /// Factory method to create the service
  static Future<OnboardingService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingService(prefs);
  }
}

/// Onboarding step definition
class OnboardingStep {
  final String title;
  final String description;
  final String? highlightKey; // Key to identify UI element to highlight

  const OnboardingStep({
    required this.title,
    required this.description,
    this.highlightKey,
  });

  /// Default onboarding steps
  static const List<OnboardingStep> defaultSteps = [
    OnboardingStep(
      title: 'Welcome to Little Star',
      description: 'Your personal AI assistant powered by local models. Let\'s get you started!',
    ),
    OnboardingStep(
      title: 'Download a Model',
      description: 'Choose from our recommended models below to get started. We suggest one based on your device.',
      highlightKey: 'recommended_models',
    ),
    OnboardingStep(
      title: 'Choose Your Feature',
      description: 'Use Model Completion for testing or AI Chat for conversations.',
      highlightKey: 'feature_cards',
    ),
    OnboardingStep(
      title: 'Manage Your Models',
      description: 'Access the Model Manager anytime to download or manage your models.',
      highlightKey: 'model_manager_card',
    ),
  ];
}
