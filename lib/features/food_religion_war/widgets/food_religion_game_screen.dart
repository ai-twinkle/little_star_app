import 'package:flutter/material.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';

class FoodReligionGameScreen extends StatefulWidget {
  const FoodReligionGameScreen({super.key});

  @override
  State<FoodReligionGameScreen> createState() => _FoodReligionGameScreenState();
}

class _FoodReligionGameScreenState extends State<FoodReligionGameScreen> {
  final _session = FoodReligionGameSession();
  bool _canLeave = false;
  bool _isExitDialogVisible = false;

  @override
  void dispose() {
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
                  child:
                      _session.stage == FoodReligionGameStage.defense
                          ? _DefensePreview(champion: _session.champion!)
                          : _MatchView(session: _session),
                ),
          ),
        ),
      ),
    );
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

class _DefensePreview extends StatelessWidget {
  const _DefensePreview({required this.champion});

  final FoodFaith champion;

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
