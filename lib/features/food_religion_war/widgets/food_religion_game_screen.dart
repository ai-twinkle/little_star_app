import 'package:flutter/material.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';

class FoodReligionGameScreen extends StatefulWidget {
  const FoodReligionGameScreen({super.key});

  @override
  State<FoodReligionGameScreen> createState() => _FoodReligionGameScreenState();
}

class _FoodReligionGameScreenState extends State<FoodReligionGameScreen> {
  late FoodReligionGameSession _session;
  final _defenseController = TextEditingController();
  bool _canLeave = false;
  bool _isExitDialogVisible = false;
  String? _defenseError;

  @override
  void initState() {
    super.initState();
    _session = FoodReligionGameSession();
  }

  @override
  void dispose() {
    _defenseController.dispose();
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
        appBar: AppBar(title: const Text('台灣食物宗教戰爭')),
        body: SafeArea(
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
                        16,
                        16,
                        16 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
                        child: switch (_session.stage) {
                          FoodReligionGameStage.semifinalZongzi ||
                          FoodReligionGameStage.semifinalCilantro ||
                          FoodReligionGameStage
                              .finalMatch => _MatchView(session: _session),
                          FoodReligionGameStage.defense => _DefenseView(
                            champion: _session.champion!,
                            controller: _defenseController,
                            characterCount: FoodReligionDefense.countCharacters(
                              _defenseController.text,
                            ),
                            errorText: _defenseError,
                            isJudging: false,
                            onChanged: (_) {
                              setState(() => _defenseError = null);
                            },
                            onSubmit: _submitDefense,
                          ),
                          FoodReligionGameStage.judging => _DefenseView(
                            champion: _session.champion!,
                            controller: _defenseController,
                            characterCount: _session.defense!.characterCount,
                            errorText: null,
                            isJudging: true,
                            onChanged: (_) {},
                            onSubmit: _submitDefense,
                          ),
                          FoodReligionGameStage.result => _ResultView(
                            champion: _session.champion!,
                            judgment: _session.judgment!,
                            onReplay: _restartGame,
                            onHome: _leaveToHome,
                          ),
                        },
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  FoodReligionDefense? _validateDefense() {
    final validation = FoodReligionDefense.validate(_defenseController.text);
    setState(() {
      _defenseError = validation.error?.message;
    });
    return validation.defense;
  }

  void _submitDefense() {
    final defense = _validateDefense();
    if (defense == null) return;
    _session.submitDefense(defense);
  }

  void _restartGame() {
    final completedSession = _session;
    setState(() {
      _session = FoodReligionGameSession();
      _defenseController.clear();
      _defenseError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completedSession.dispose();
    });
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
    if (shouldLeave != true || !mounted) return;
    _leaveToHome();
  }
}

class _MatchView extends StatelessWidget {
  const _MatchView({required this.session});

  final FoodReligionGameSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          label: '對戰進度：${session.progressLabel}',
          child: ExcludeSemantics(
            child: Text(session.progressLabel, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 8),
        const Text('點擊你支持的飲食信仰', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        for (final (index, faith) in session.contenders.indexed) ...[
          if (index > 0 && session.stage == FoodReligionGameStage.finalMatch)
            const _VersusBadge()
          else if (index > 0)
            const SizedBox(height: 16),
          _FaithCard(
            faith: faith,
            isSelected: session.selectedFaith == faith,
            onTap:
                session.isSelectionLocked ? null : () => session.select(faith),
          ),
        ],
      ],
    );
  }
}

class _VersusBadge extends StatelessWidget {
  const _VersusBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const ValueKey('final-match-versus'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'VS',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _DefenseView extends StatelessWidget {
  const _DefenseView({
    required this.champion,
    required this.controller,
    required this.characterCount,
    required this.errorText,
    required this.isJudging,
    required this.onChanged,
    required this.onSubmit,
  });

  final FoodFaith champion;
  final TextEditingController controller;
  final int characterCount;
  final String? errorText;
  final bool isJudging;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '你的終極飲食信仰',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Text(
          champion.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        Semantics(
          container: true,
          label: '固定質疑：${champion.finalChallenge}',
          child: ExcludeSemantics(
            child: Text(champion.finalChallenge, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          enabled: !isJudging,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: '你的辯護',
            hintText: '用一句話捍衛你的信仰',
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: isJudging ? null : (_) => onSubmit(),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),
        FilledButton(
          onPressed: isJudging ? null : onSubmit,
          child: const Text('送出辯護'),
        ),
        if (isJudging) ...[
          const SizedBox(height: 24),
          const ExcludeSemantics(
            child: Center(child: CircularProgressIndicator()),
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            label: '等待裁決：AI 鄉民評審正在審判…',
            child: ExcludeSemantics(
              child: Text('AI 鄉民評審正在審判…', textAlign: TextAlign.center),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.champion,
    required this.judgment,
    required this.onReplay,
    required this.onHome,
  });

  final FoodFaith champion;
  final FoodReligionJudgment judgment;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '冠軍',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        _ChampionCelebration(champion: champion),
        const SizedBox(height: 4),
        Text(
          champion.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          label: '判決：${judgment.verdict.label}',
          child: ExcludeSemantics(
            child: Text(
              judgment.verdict.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(judgment.roast, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          label: '備援提示：AI 主持人暫時離線，改由備援鄉民評審裁決！',
          child: ExcludeSemantics(
            child: Text(
              'AI 主持人暫時離線，改由備援鄉民評審裁決！',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const Spacer(),
        FilledButton(onPressed: onReplay, child: const Text('再玩一次')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onHome, child: const Text('回首頁')),
      ],
    );
  }
}

class _ChampionCelebration extends StatelessWidget {
  const _ChampionCelebration({required this.champion});

  final FoodFaith champion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      key: const ValueKey('champion-confetti'),
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 28,
            top: 18,
            child: Icon(Icons.auto_awesome, color: colors.tertiary, size: 24),
          ),
          Positioned(
            right: 34,
            top: 8,
            child: Icon(Icons.celebration, color: colors.primary, size: 30),
          ),
          Positioned(
            left: 50,
            bottom: 26,
            child: Icon(Icons.circle, color: colors.secondary, size: 10),
          ),
          Positioned(
            right: 52,
            bottom: 34,
            child: Icon(Icons.star, color: colors.tertiary, size: 18),
          ),
          Image.asset(
            champion.characterAssetPath,
            key: ValueKey('food-faith-art-${champion.name}'),
            height: 160,
            fit: BoxFit.contain,
            semanticLabel: champion.label,
          ),
        ],
      ),
    );
  }
}

class _FaithCard extends StatelessWidget {
  const _FaithCard({
    required this.faith,
    required this.isSelected,
    required this.onTap,
  });

  final FoodFaith faith;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('winner-feedback-${faith.name}'),
      tween: Tween(end: isSelected ? 1 : 0),
      duration: FoodReligionGameSession.selectionFeedbackDuration,
      curve: Curves.easeInOut,
      builder: (context, progress, child) {
        final pulse = 4 * progress * (1 - progress);
        final colorScheme = Theme.of(context).colorScheme;
        return Transform(
          key: ValueKey('winner-motion-${faith.name}'),
          transform:
              Matrix4.identity()
                ..setEntry(0, 0, 1 + 0.08 * pulse)
                ..setEntry(1, 1, 1 + 0.08 * pulse)
                ..setEntry(1, 3, -14 * pulse),
          alignment: Alignment.center,
          child: DecoratedBox(
            key: ValueKey('winner-glow-${faith.name}'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(
                            alpha: 0.55 * pulse,
                          ),
                          blurRadius: 28 * pulse,
                          spreadRadius: 5 * pulse,
                        ),
                      ]
                      : const [],
            ),
            child: child,
          ),
        );
      },
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label:
            '${faith.label}，${isSelected
                ? '已選擇並晉級，已鎖定'
                : onTap == null
                ? '已鎖定'
                : '未選擇'}',
        button: true,
        enabled: onTap != null,
        selected: isSelected,
        child: Card(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    faith.characterAssetPath,
                    key: ValueKey('food-faith-art-${faith.name}'),
                    height: 112,
                    fit: BoxFit.contain,
                    semanticLabel: faith.label,
                  ),
                  const SizedBox(height: 8),
                  Text(faith.label, textAlign: TextAlign.center),
                  if (isSelected)
                    Text(
                      '${faith.label}晉級！',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
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
}
