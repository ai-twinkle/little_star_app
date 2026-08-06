import 'package:flutter/material.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
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
                (context, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: switch (_session.stage) {
                    FoodReligionGameStage.semifinalZongzi ||
                    FoodReligionGameStage.semifinalCilantro ||
                    FoodReligionGameStage
                        .finalMatch => _MatchView(session: _session),
                    FoodReligionGameStage.defense => _DefenseView(
                      champion: _session.champion!,
                      controller: _defenseController,
                      characterCount: _defenseController.text.characters.length,
                      errorText: _defenseError,
                      onChanged: (_) {
                        setState(() => _defenseError = null);
                      },
                      onSubmit: _submitDefense,
                    ),
                    FoodReligionGameStage.judging => const _JudgingView(),
                    FoodReligionGameStage.result => _ResultView(
                      champion: _session.champion!,
                      judgment: _session.judgment!,
                      onReplay: _restartGame,
                      onHome: _leaveToHome,
                    ),
                  },
                ),
          ),
        ),
      ),
    );
  }

  bool _validateDefense() {
    final defenseLength = _defenseController.text.trim().characters.length;
    final error = switch (defenseLength) {
      0 => '請輸入 1～50 字的辯護',
      > 50 => '最多只能輸入 50 字',
      _ => null,
    };
    setState(() {
      _defenseError = error;
    });
    return error == null;
  }

  void _submitDefense() {
    if (!_validateDefense()) return;
    _session.submitDefense(_defenseController.text);
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

    setState(() => _canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
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
        Text(session.progressLabel, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('點擊你支持的飲食信仰', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        for (final (index, faith) in session.contenders.indexed) ...[
          if (index > 0) const SizedBox(height: 16),
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

class _DefenseView extends StatelessWidget {
  const _DefenseView({
    required this.champion,
    required this.controller,
    required this.characterCount,
    required this.errorText,
    required this.onChanged,
    required this.onSubmit,
  });

  final FoodFaith champion;
  final TextEditingController controller;
  final int characterCount;
  final String? errorText;
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
        Text(champion.finalChallenge, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: '你的辯護',
            hintText: '用一句話捍衛你的信仰',
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 8),
        Text('$characterCount / 50', textAlign: TextAlign.end),
        const SizedBox(height: 16),
        FilledButton(onPressed: onSubmit, child: const Text('送出辯護')),
      ],
    );
  }
}

class _JudgingView extends StatelessWidget {
  const _JudgingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('AI 鄉民評審正在審判…'),
        ],
      ),
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
          champion.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        Text(
          judgment.verdict.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(judgment.roast, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        const Text('AI 主持人暫時離線，改由備援鄉民評審裁決！', textAlign: TextAlign.center),
        const Spacer(),
        FilledButton(onPressed: onReplay, child: const Text('再玩一次')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onHome, child: const Text('回首頁')),
      ],
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
    return AnimatedScale(
      scale: isSelected ? 1.05 : 1,
      duration: const Duration(milliseconds: 200),
      child: Card(
        color:
            isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(faith.label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
