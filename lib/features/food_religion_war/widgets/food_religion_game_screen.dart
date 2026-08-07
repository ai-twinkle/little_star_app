import 'package:flutter/material.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';

class FoodReligionGameScreen extends StatefulWidget {
  const FoodReligionGameScreen({
    super.key,
    this.judgmentServiceFactory,
    this.randomizer,
  });

  final FoodReligionJudgmentService Function()? judgmentServiceFactory;
  final FoodReligionGameRandomizer? randomizer;

  @override
  State<FoodReligionGameScreen> createState() => _FoodReligionGameScreenState();
}

class _FoodReligionGameScreenState extends State<FoodReligionGameScreen> {
  late final FoodReligionGameRandomizer _randomizer;
  late FoodReligionGameSession _session;
  final _defenseController = TextEditingController();
  bool _canLeave = false;
  bool _isExitDialogVisible = false;
  String? _defenseError;

  @override
  void initState() {
    super.initState();
    _randomizer = widget.randomizer ?? DefaultFoodReligionGameRandomizer();
    _session = _createSession();
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
                          FoodReligionGameStage.choice => _ChoiceView(
                            session: _session,
                          ),
                          FoodReligionGameStage.draw => _DrawView(
                            beliefSlate: _session.beliefSlate,
                            onDraw: _session.drawDefense,
                          ),
                          FoodReligionGameStage.defense => _DefenseView(
                            drawnFaith: _session.drawnFaith!,
                            controller: _defenseController,
                            characterCount: FoodReligionDefense.countCharacters(
                              _defenseController.text,
                            ),
                            errorText: _defenseError,
                            isJudging: false,
                            models: _session.models,
                            selectedModel: _session.selectedModel,
                            isDiscoveringModels: _session.isDiscoveringModels,
                            onModelChanged: _session.selectModel,
                            onChanged:
                                (_) => setState(() => _defenseError = null),
                            onSubmit: _submitDefense,
                          ),
                          FoodReligionGameStage.judging => _DefenseView(
                            drawnFaith: _session.drawnFaith!,
                            controller: _defenseController,
                            characterCount: _session.defense!.characterCount,
                            errorText: null,
                            isJudging: true,
                            models: _session.models,
                            selectedModel: _session.selectedModel,
                            isDiscoveringModels: _session.isDiscoveringModels,
                            onModelChanged: _session.selectModel,
                            onChanged: (_) {},
                            onSubmit: _submitDefense,
                          ),
                          FoodReligionGameStage.result => _ResultView(
                            drawnFaith: _session.drawnFaith!,
                            beliefSlate: _session.beliefSlate,
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

  void _submitDefense() {
    final validation = FoodReligionDefense.validate(_defenseController.text);
    setState(() => _defenseError = validation.error?.message);
    final defense = validation.defense;
    if (defense != null) _session.submitDefense(defense);
  }

  void _restartGame() {
    final completedSession = _session;
    setState(() {
      _session = _createSession(
        previousDrawnFaith: completedSession.drawnFaith,
      );
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
        previousDrawnFaith: previousDrawnFaith,
      );

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

class _ProgressLabel extends StatelessWidget {
  const _ProgressLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: '遊戲進度：$label',
    child: ExcludeSemantics(child: Text(label, textAlign: TextAlign.center)),
  );
}

class _ChoiceView extends StatelessWidget {
  const _ChoiceView({required this.session});

  final FoodReligionGameSession session;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ProgressLabel(session.progressLabel),
      const SizedBox(height: 8),
      Text(session.currentRound.topic, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text('選一個你支持的飲食立場', textAlign: TextAlign.center),
      const SizedBox(height: 16),
      for (final (index, faith) in session.contenders.indexed) ...[
        if (index > 0) const _VersusBadge(),
        _FaithCard(
          faith: faith,
          isSelected: session.selectedFaith == faith,
          onTap: session.isSelectionLocked ? null : () => session.select(faith),
        ),
      ],
    ],
  );
}

class _VersusBadge extends StatelessWidget {
  const _VersusBadge();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('VS', style: Theme.of(context).textTheme.labelLarge),
    ),
  );
}

class _DrawView extends StatelessWidget {
  const _DrawView({required this.beliefSlate, required this.onDraw});

  final List<FoodFaith> beliefSlate;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _ProgressLabel('辯護抽籤'),
      const SizedBox(height: 16),
      Text(
        '本局信仰清單',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text('四個選擇都已保留；接著從中抽出一項辯護。', textAlign: TextAlign.center),
      const SizedBox(height: 20),
      _BeliefSlate(faiths: beliefSlate),
      const Spacer(),
      FilledButton(onPressed: onDraw, child: const Text('抽出辯護立場')),
    ],
  );
}

class _DefenseView extends StatelessWidget {
  const _DefenseView({
    required this.drawnFaith,
    required this.controller,
    required this.characterCount,
    required this.errorText,
    required this.isJudging,
    required this.models,
    required this.selectedModel,
    required this.isDiscoveringModels,
    required this.onModelChanged,
    required this.onChanged,
    required this.onSubmit,
  });

  final FoodFaith drawnFaith;
  final TextEditingController controller;
  final int characterCount;
  final String? errorText;
  final bool isJudging;
  final List<FoodReligionModel> models;
  final FoodReligionModel? selectedModel;
  final bool isDiscoveringModels;
  final ValueChanged<FoodReligionModel?> onModelChanged;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _ProgressLabel('立場辯護'),
      const SizedBox(height: 8),
      const Text('本次抽中', textAlign: TextAlign.center),
      Text(
        drawnFaith.label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Semantics(
        container: true,
        label: '固定質疑：${drawnFaith.finalChallenge}',
        child: ExcludeSemantics(
          child: Text(drawnFaith.finalChallenge, textAlign: TextAlign.center),
        ),
      ),
      const SizedBox(height: 16),
      if (isDiscoveringModels)
        const Text('正在發現已安裝模型…', textAlign: TextAlign.center)
      else if (models.isEmpty)
        const Text('目前沒有已安裝模型，送出後將使用備援裁決。', textAlign: TextAlign.center)
      else
        DropdownButtonFormField<FoodReligionModel>(
          initialValue: selectedModel,
          decoration: const InputDecoration(
            labelText: '裁決模型',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final model in models)
              DropdownMenuItem(value: model, child: Text(model.label)),
          ],
          onChanged: isJudging ? null : onModelChanged,
        ),
      const SizedBox(height: 12),
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
        onSubmitted: isJudging ? null : (_) => onSubmit(),
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
        onPressed: isJudging ? null : onSubmit,
        child: const Text('送出辯護'),
      ),
      if (isJudging) ...[
        const SizedBox(height: 16),
        const ExcludeSemantics(
          child: Center(child: CircularProgressIndicator()),
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _ProgressLabel('裁決結果'),
      const SizedBox(height: 6),
      const Text('本次抽中', textAlign: TextAlign.center),
      _FaithArtwork(faith: drawnFaith, height: 112),
      Text(
        drawnFaith.label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      const Text('本次抽中；四個選擇都會保留。', textAlign: TextAlign.center),
      const SizedBox(height: 12),
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
      Text(judgment.roast, textAlign: TextAlign.center),
      if (judgment.isFallback) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          label: '備援提示：AI 主持人暫時離線，改由備援鄉民評審裁決！',
          child: const ExcludeSemantics(
            child: Text('AI 主持人暫時離線，改由備援鄉民評審裁決！', textAlign: TextAlign.center),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Text(
        '本局信仰清單',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      _BeliefSlate(faiths: beliefSlate, drawnFaith: drawnFaith),
      const Spacer(),
      FilledButton(onPressed: onReplay, child: const Text('再玩一次')),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: onHome, child: const Text('回首頁')),
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
          avatar: Icon(
            faith == drawnFaith ? Icons.casino : Icons.check,
            size: 18,
          ),
          label: Text('${faith.label}${faith == drawnFaith ? '（抽中）' : ''}'),
        ),
    ],
  );
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
    child: Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
          width: 3,
        ),
      ),
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
                const Text('立場已記錄'),
                const SizedBox(width: 6),
                const Icon(Icons.check_circle),
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
  Widget build(BuildContext context) {
    final path = faith.characterAssetPath;
    if (path == null) {
      return SizedBox(
        key: ValueKey('food-faith-art-${faith.name}'),
        width: height,
        height: height,
        child: const Icon(Icons.restaurant, size: 48),
      );
    }
    return Image.asset(
      path,
      key: ValueKey('food-faith-art-${faith.name}'),
      height: height,
      width: height,
      fit: BoxFit.contain,
      semanticLabel: faith.label,
    );
  }
}
