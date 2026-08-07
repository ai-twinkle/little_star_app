import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/ui/models/widgets/model_manager_screen.dart';

abstract final class _ArenaColors {
  static const night = Color(0xFF071419);
  static const panel = Color(0xFF122329);
  static const panelRaised = Color(0xFF182A30);
  static const metal = Color(0xFF415158);
  static const marquee = Color(0xFF7E2F26);
  static const marqueeDark = Color(0xFF4E1D1A);
  static const redSeat = Color(0xFFD75B51);
  static const cyanSeat = Color(0xFF58C6C8);
  static const amber = Color(0xFFF5BE5B);
  static const cream = Color(0xFFFFF3DB);
  static const muted = Color(0xFFB8C1C1);
}

class FoodReligionGameScreen extends StatefulWidget {
  const FoodReligionGameScreen({
    super.key,
    this.judgmentServiceFactory,
    this.randomizer,
    this.runState,
    this.recommendedModelsPageBuilder,
  });

  final FoodReligionJudgmentService Function()? judgmentServiceFactory;
  final FoodReligionGameRandomizer? randomizer;
  final FoodReligionGameRunState? runState;
  final WidgetBuilder? recommendedModelsPageBuilder;

  @override
  State<FoodReligionGameScreen> createState() => _FoodReligionGameScreenState();
}

class _FoodReligionGameScreenState extends State<FoodReligionGameScreen> {
  late final FoodReligionGameRandomizer _randomizer;
  late final FoodReligionGameRunState _runState;
  late FoodReligionGameSession _session;
  final _defenseController = TextEditingController();
  bool _canLeave = false;
  bool _isExitDialogVisible = false;
  bool _isMissingModelReminderScheduled = false;
  FoodReligionGameStage _lastFeedbackStage = FoodReligionGameStage.choice;
  String? _defenseError;

  @override
  void initState() {
    super.initState();
    _randomizer = widget.randomizer ?? DefaultFoodReligionGameRandomizer();
    _runState =
        widget.runState ??
        (widget.randomizer == null
            ? FoodReligionGameRunState.shared
            : FoodReligionGameRunState());
    _session = _createSession();
    _session.addListener(_handleSessionChanged);
  }

  @override
  void dispose() {
    _defenseController.dispose();
    _session.removeListener(_handleSessionChanged);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        key: const ValueKey('night-market-arena'),
        backgroundColor: _ArenaColors.night,
        body: Theme(
          data: _arenaTheme(context),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _session,
              builder:
                  (context, _) => CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          16 + MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1180),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Row(
                                    children: [
                                      BackButton(color: _ArenaColors.cream),
                                      SizedBox(width: 8),
                                      Expanded(child: _MainMarquee()),
                                      SizedBox(width: 48),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '四次抉擇・一次辯護',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: _ArenaColors.muted),
                                  ),
                                  const SizedBox(height: 12),
                                  _ProgressLabel(
                                    _session.progressLabel,
                                    stage: _session.stage,
                                    choiceIndex: _session.choiceIndex,
                                  ),
                                  const SizedBox(height: 18),
                                  switch (_session.stage) {
                                    FoodReligionGameStage.choice => _ChoiceView(
                                      session: _session,
                                    ),
                                    FoodReligionGameStage.draw => _DrawView(
                                      beliefSlate: _session.beliefSlate,
                                      onDraw: _drawDefense,
                                    ),
                                    FoodReligionGameStage.defense =>
                                      _buildDefenseView(isJudging: false),
                                    FoodReligionGameStage.judging =>
                                      _buildDefenseView(isJudging: true),
                                    FoodReligionGameStage.result => _ResultView(
                                      drawnFaith: _session.drawnFaith!,
                                      beliefSlate: _session.beliefSlate,
                                      judgment: _session.judgment!,
                                      onReplay: _restartGame,
                                      onHome: _leaveToHome,
                                    ),
                                  },
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _arenaTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _ArenaColors.night,
      colorScheme: const ColorScheme.dark(
        primary: _ArenaColors.amber,
        onPrimary: Color(0xFF2B1B05),
        secondary: _ArenaColors.cyanSeat,
        surface: _ArenaColors.panel,
        onSurface: _ArenaColors.cream,
        outline: _ArenaColors.metal,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: _ArenaColors.cream,
        displayColor: _ArenaColors.cream,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _ArenaColors.amber,
          foregroundColor: const Color(0xFF2B1B05),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _ArenaColors.night,
        border: OutlineInputBorder(),
      ),
    );
  }

  void _submitDefense() {
    final validation = FoodReligionDefense.validate(_defenseController.text);
    setState(() => _defenseError = validation.error?.message);
    final defense = validation.defense;
    if (defense != null) _session.submitDefense(defense);
  }

  Widget _buildDefenseView({required bool isJudging}) => _DefenseView(
    drawnFaith: _session.drawnFaith!,
    beliefSlate: _session.beliefSlate,
    controller: _defenseController,
    characterCount:
        isJudging
            ? _session.defense!.characterCount
            : FoodReligionDefense.countCharacters(_defenseController.text),
    errorText: isJudging ? null : _defenseError,
    isJudging: isJudging,
    models: _session.models,
    selectedModel: _session.selectedModel,
    isDiscoveringModels: _session.isDiscoveringModels,
    onModelChanged: _session.selectModel,
    onOpenRecommendedModels: _openRecommendedModels,
    onChanged: isJudging ? (_) {} : (_) => setState(() => _defenseError = null),
    onSubmit: _submitDefense,
  );

  void _drawDefense() {
    HapticFeedback.lightImpact();
    _session.drawDefense();
    final drawnFaith = _session.drawnFaith;
    if (drawnFaith != null) _runState.recordDraw(drawnFaith);
  }

  void _restartGame() {
    final completedSession = _session;
    completedSession.removeListener(_handleSessionChanged);
    setState(() {
      _session = _createSession(
        previousDrawnFaith: completedSession.drawnFaith,
      );
      _lastFeedbackStage = FoodReligionGameStage.choice;
      _session.addListener(_handleSessionChanged);
      _defenseController.clear();
      _defenseError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => completedSession.dispose(),
    );
  }

  FoodReligionGameSession _createSession({FoodFaith? previousDrawnFaith}) =>
      FoodReligionGameSession(
        judgmentService: widget.judgmentServiceFactory?.call(),
        randomizer: _randomizer,
        previousDrawnFaith: previousDrawnFaith ?? _runState.lastDrawnFaith,
      );

  void _handleSessionChanged() {
    if (_session.stage != _lastFeedbackStage) {
      _lastFeedbackStage = _session.stage;
      if (_session.stage == FoodReligionGameStage.result) {
        HapticFeedback.mediumImpact();
      }
    }
    if (_isMissingModelReminderScheduled ||
        _session.isDiscoveringModels ||
        _session.models.isNotEmpty ||
        !_runState.shouldShowMissingModelReminder) {
      return;
    }
    _isMissingModelReminderScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showMissingModelReminder();
    });
  }

  Future<void> _showMissingModelReminder() async {
    _runState.recordMissingModelReminderShown();
    final openRecommendedModels = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('AI 評審還沒來報到'),
            content: const Text('目前沒有可用模型，但不影響遊戲；你仍可完成整局並取得備援裁決。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('前往推薦模型'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('先玩再說'),
              ),
            ],
          ),
    );
    if (openRecommendedModels == true && mounted) {
      await _openRecommendedModels();
    }
  }

  Future<void> _openRecommendedModels() async {
    final activeSession = _session;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            widget.recommendedModelsPageBuilder ??
            (_) => const RecommendedModelManagerScreen(),
      ),
    );
    if (mounted && identical(_session, activeSession)) {
      await activeSession.rediscoverModels();
    }
  }

  void _leaveToHome() {
    setState(() => _canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _confirmExit() async {
    if (_isExitDialogVisible) return;
    _isExitDialogVisible = true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('確定離開本局？'),
            content: const Text('離開後，本局進度將會清除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('確定離開'),
              ),
            ],
          ),
    );
    _isExitDialogVisible = false;
    if (shouldLeave == true && mounted) _leaveToHome();
  }
}

class _MainMarquee extends StatelessWidget {
  const _MainMarquee();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('main-marquee'),
    constraints: const BoxConstraints(maxWidth: 430),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_ArenaColors.marquee, _ArenaColors.marqueeDark],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _ArenaColors.redSeat, width: 2),
      boxShadow: const [
        BoxShadow(color: _ArenaColors.metal, blurRadius: 0, spreadRadius: 5),
        BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 5)),
      ],
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lightbulb, color: _ArenaColors.amber, size: 18),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            '台灣食物宗教戰爭',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ArenaColors.cream,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        SizedBox(width: 10),
        Icon(Icons.lightbulb, color: _ArenaColors.amber, size: 18),
      ],
    ),
  );
}

class _ProgressLabel extends StatelessWidget {
  const _ProgressLabel(
    this.label, {
    required this.stage,
    required this.choiceIndex,
  });

  final String label;
  final FoodReligionGameStage stage;
  final int choiceIndex;

  @override
  Widget build(BuildContext context) {
    final activeStep = stage == FoodReligionGameStage.choice ? choiceIndex : 4;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '遊戲進度：$label',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ArenaColors.amber,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < 5; index++) ...[
                  if (index > 0)
                    Container(
                      width: 24,
                      height: 1,
                      color:
                          index <= activeStep
                              ? _ArenaColors.amber
                              : _ArenaColors.metal,
                    ),
                  _ProgressDot(
                    label: index < 4 ? '${index + 1}' : '籤',
                    isActive: index == activeStep,
                    isComplete: index < activeStep,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({
    required this.label,
    required this.isActive,
    required this.isComplete,
  });

  final String label;
  final bool isActive;
  final bool isComplete;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isComplete ? _ArenaColors.amber : _ArenaColors.panel,
      shape: BoxShape.circle,
      border: Border.all(
        color: isActive ? _ArenaColors.amber : _ArenaColors.metal,
        width: isActive ? 2 : 1,
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        color:
            isComplete
                ? _ArenaColors.night
                : isActive
                ? _ArenaColors.amber
                : _ArenaColors.muted,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ChoiceView extends StatelessWidget {
  const _ChoiceView({required this.session});

  final FoodReligionGameSession session;

  @override
  Widget build(BuildContext context) => _ArenaPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          session.currentRound.topic,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ArenaColors.amber,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          session.isSelectionLocked ? '這次選擇，記下來了' : '你站哪一邊？',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          session.isSelectionLocked ? '選擇已加入本局信仰清單' : '選一個你支持的飲食立場',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ArenaColors.muted),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = <Widget>[
              for (final (index, faith) in session.contenders.indexed)
                _FaithCard(
                  key: ValueKey(
                    index == 0 ? 'red-choice-seat' : 'cyan-choice-seat',
                  ),
                  faith: faith,
                  seatColor:
                      index == 0 ? _ArenaColors.redSeat : _ArenaColors.cyanSeat,
                  isSelected: session.selectedFaith == faith,
                  onTap:
                      session.isSelectionLocked
                          ? null
                          : () {
                            HapticFeedback.selectionClick();
                            session.select(faith);
                          },
                ),
            ];
            if (constraints.maxWidth >= 760) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 14),
                  const _VersusBadge(),
                  const SizedBox(width: 14),
                  Expanded(child: cards[1]),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cards[0], const _VersusBadge(), cards[1]],
            );
          },
        ),
        if (session.isSelectionLocked) ...[
          const SizedBox(height: 14),
          const _RecordedBanner(),
        ],
      ],
    ),
  );
}

class _VersusBadge extends StatelessWidget {
  const _VersusBadge();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _ArenaColors.night,
          shape: BoxShape.circle,
          border: Border.all(color: _ArenaColors.metal),
        ),
        child: const Text(
          'VS',
          style: TextStyle(
            color: _ArenaColors.amber,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _DrawView extends StatelessWidget {
  const _DrawView({required this.beliefSlate, required this.onDraw});

  final List<FoodFaith> beliefSlate;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) => _ResponsiveArenaLayout(
    primary: _ArenaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '四次選擇都已留下',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ArenaColors.amber,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '本局信仰清單',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            '四個選擇都已保留；接著從中抽出一項辯護。',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ArenaColors.muted),
          ),
          const SizedBox(height: 20),
          _BeliefSlate(faiths: beliefSlate),
        ],
      ),
    ),
    secondary: _ArenaPanel(
      emphasized: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '現在抽出辯護立場',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            '只會從你選過的四個立場抽出一項，抽出後不可重抽。',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ArenaColors.muted),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onDraw, child: const Text('抽出辯護立場')),
        ],
      ),
    ),
  );
}

class _DefenseView extends StatelessWidget {
  const _DefenseView({
    required this.drawnFaith,
    required this.beliefSlate,
    required this.controller,
    required this.characterCount,
    required this.errorText,
    required this.isJudging,
    required this.models,
    required this.selectedModel,
    required this.isDiscoveringModels,
    required this.onModelChanged,
    required this.onOpenRecommendedModels,
    required this.onChanged,
    required this.onSubmit,
  });

  final FoodFaith drawnFaith;
  final List<FoodFaith> beliefSlate;
  final TextEditingController controller;
  final int characterCount;
  final String? errorText;
  final bool isJudging;
  final List<FoodReligionModel> models;
  final FoodReligionModel? selectedModel;
  final bool isDiscoveringModels;
  final ValueChanged<FoodReligionModel?> onModelChanged;
  final VoidCallback onOpenRecommendedModels;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => _ResponsiveArenaLayout(
    primary: _ArenaPanel(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DrawnStanceHero(faith: drawnFaith, artworkHeight: 120),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            enabled: !isJudging,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: '你的辯護',
              hintText: '用一句話捍衛這個立場',
              errorText: errorText,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted:
                isJudging || isDiscoveringModels ? null : (_) => onSubmit(),
          ),
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            label: '字數：$characterCount / 50',
            child: ExcludeSemantics(
              child: Text('$characterCount / 50', textAlign: TextAlign.end),
            ),
          ),
          if (errorText != null)
            Semantics(
              liveRegion: true,
              label: '錯誤：$errorText',
              child: const SizedBox.shrink(),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isJudging || isDiscoveringModels ? null : onSubmit,
            child: const Text('送出辯護'),
          ),
          if (isJudging) ...[
            const SizedBox(height: 16),
            ExcludeSemantics(
              child: Center(
                child:
                    MediaQuery.disableAnimationsOf(context)
                        ? const Icon(
                          Icons.hourglass_top,
                          color: _ArenaColors.amber,
                        )
                        : const CircularProgressIndicator(),
              ),
            ),
            Semantics(
              liveRegion: true,
              label: '等待裁決：AI 鄉民評審正在審判…',
              child: const ExcludeSemantics(
                child: Text('AI 鄉民評審正在審判…', textAlign: TextAlign.center),
              ),
            ),
          ],
        ],
      ),
    ),
    secondary: _ArenaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '本局信仰清單',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _BeliefSlate(faiths: beliefSlate, drawnFaith: drawnFaith),
          const SizedBox(height: 18),
          if (isDiscoveringModels)
            const Text('正在發現已安裝模型…', textAlign: TextAlign.center)
          else if (models.isEmpty)
            const Text(
              '目前沒有已安裝模型，送出後將使用備援裁決。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _ArenaColors.muted),
            )
          else
            DropdownButtonFormField<FoodReligionModel>(
              initialValue: selectedModel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '裁決模型',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final model in models)
                  DropdownMenuItem(
                    value: model,
                    child: Text(
                      model.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: isJudging ? null : onModelChanged,
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed:
                isJudging || isDiscoveringModels
                    ? null
                    : onOpenRecommendedModels,
            icon: const Icon(Icons.download_outlined),
            label: const Text('前往推薦模型'),
          ),
        ],
      ),
    ),
  );
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.drawnFaith,
    required this.beliefSlate,
    required this.judgment,
    required this.onReplay,
    required this.onHome,
  });

  final FoodFaith drawnFaith;
  final List<FoodFaith> beliefSlate;
  final FoodReligionJudgment judgment;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => _ResponsiveArenaLayout(
    primary: _ArenaPanel(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DrawnStanceHero(faith: drawnFaith, artworkHeight: 156),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            label: '判決：${judgment.verdict.label}',
            child: ExcludeSemantics(
              child: Text(
                judgment.verdict.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _ArenaColors.cream,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Text(judgment.roast, textAlign: TextAlign.center),
          if (judgment.isFallback) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              label: '備援提示：AI 主持人暫時離線，改由備援鄉民評審裁決！',
              child: const ExcludeSemantics(
                child: Text(
                  'AI 主持人暫時離線，改由備援鄉民評審裁決！',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _ArenaColors.muted),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: onReplay, child: const Text('再玩一次')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onHome, child: const Text('回首頁')),
        ],
      ),
    ),
    secondary: _ArenaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '本次抽中；四個選擇都會保留。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ArenaColors.amber,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '本局信仰清單',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _BeliefSlate(faiths: beliefSlate, drawnFaith: drawnFaith),
        ],
      ),
    ),
  );
}

class _DrawnStanceHero extends StatelessWidget {
  const _DrawnStanceHero({required this.faith, required this.artworkHeight});

  final FoodFaith faith;
  final double artworkHeight;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '本次抽中',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _ArenaColors.amber,
          fontWeight: FontWeight.w800,
        ),
      ),
      _FaithArtwork(faith: faith, height: artworkHeight),
      Text(
        faith.label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      Semantics(
        container: true,
        label: '固定質疑：${faith.finalChallenge}',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _ArenaColors.night,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _ArenaColors.metal),
            ),
            child: Text(faith.finalChallenge, textAlign: TextAlign.center),
          ),
        ),
      ),
    ],
  );
}

class _BeliefSlate extends StatelessWidget {
  const _BeliefSlate({required this.faiths, this.drawnFaith});

  final List<FoodFaith> faiths;
  final FoodFaith? drawnFaith;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final faith in faiths)
        Chip(
          avatar: Stack(
            clipBehavior: Clip.none,
            children: [
              Image.asset(
                faith.characterAssetPath,
                key: ValueKey('belief-slate-art-${faith.name}'),
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              if (faith == drawnFaith)
                const Positioned(
                  right: -4,
                  bottom: -3,
                  child: Icon(Icons.casino, size: 13),
                ),
            ],
          ),
          label: Text('${faith.label}${faith == drawnFaith ? '（抽中）' : ''}'),
        ),
    ],
  );
}

class _ResponsiveArenaLayout extends StatelessWidget {
  const _ResponsiveArenaLayout({
    required this.primary,
    required this.secondary,
  });

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final orderedPrimary = Semantics(
        container: true,
        explicitChildNodes: true,
        sortKey: const OrdinalSortKey(0),
        child: primary,
      );
      final orderedSecondary = Semantics(
        container: true,
        explicitChildNodes: true,
        sortKey: const OrdinalSortKey(1),
        child: secondary,
      );
      if (constraints.maxWidth >= 760) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: orderedPrimary),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: orderedSecondary),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          orderedPrimary,
          const SizedBox(height: 14),
          orderedSecondary,
        ],
      );
    },
  );
}

class _ArenaPanel extends StatelessWidget {
  const _ArenaPanel({required this.child, this.emphasized = false});

  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 400 ? 14 : 18),
    decoration: BoxDecoration(
      color: _ArenaColors.panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: emphasized ? _ArenaColors.amber : _ArenaColors.metal,
        width: emphasized ? 1.5 : 1,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 8)),
      ],
    ),
    child: child,
  );
}

class _RecordedBanner extends StatelessWidget {
  const _RecordedBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF5B321B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _ArenaColors.amber),
    ),
    child: const Row(
      children: [
        Expanded(
          child: Text('立場已記錄', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

class _FaithCard extends StatelessWidget {
  const _FaithCard({
    super.key,
    required this.faith,
    required this.seatColor,
    required this.isSelected,
    required this.onTap,
  });

  final FoodFaith faith;
  final Color seatColor;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    label:
        '${faith.label}，${isSelected
            ? '立場已記錄，已鎖定'
            : onTap == null
            ? '已鎖定'
            : '未選擇'}',
    button: true,
    enabled: onTap != null,
    selected: isSelected,
    child: AnimatedContainer(
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color:
            isSelected
                ? Color.alphaBlend(
                  _ArenaColors.amber.withValues(alpha: 0.12),
                  _ArenaColors.panelRaised,
                )
                : _ArenaColors.panelRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _ArenaColors.amber : seatColor,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSelected ? _ArenaColors.amber : seatColor).withValues(
              alpha: isSelected ? 0.32 : 0.12,
            ),
            blurRadius: isSelected ? 18 : 8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              _FaithArtwork(faith: faith, height: 76),
              const SizedBox(width: 12),
              Expanded(child: Text(faith.label, textAlign: TextAlign.center)),
              if (isSelected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle, color: _ArenaColors.amber),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _FaithArtwork extends StatelessWidget {
  const _FaithArtwork({required this.faith, required this.height});

  final FoodFaith faith;
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
    faith.characterAssetPath,
    key: ValueKey('food-faith-art-${faith.name}'),
    height: height,
    width: height,
    fit: BoxFit.contain,
    semanticLabel: faith.label,
  );
}
