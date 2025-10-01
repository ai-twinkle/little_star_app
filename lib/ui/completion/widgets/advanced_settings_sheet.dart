import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bottom sheet for advanced completion settings
class AdvancedSettingsSheet extends StatefulWidget {
  final int maxTokens;
  final List<String> stopSequences;
  final double temperature;
  final int topK;
  final double topP;
  final String systemPrompt;
  final Function({
    int? maxTokens,
    List<String>? stopSequences,
    double? temperature,
    int? topK,
    double? topP,
    String? systemPrompt,
  }) onApply;
  final VoidCallback onReset;

  const AdvancedSettingsSheet({
    super.key,
    required this.maxTokens,
    required this.stopSequences,
    required this.temperature,
    required this.topK,
    required this.topP,
    required this.systemPrompt,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<AdvancedSettingsSheet> createState() => _AdvancedSettingsSheetState();
}

class _AdvancedSettingsSheetState extends State<AdvancedSettingsSheet> {
  late int _maxTokens;
  late List<String> _stopSequences;
  late double _temperature;
  late int _topK;
  late double _topP;
  late String _systemPrompt;

  final TextEditingController _stopSequencesController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _maxTokens = widget.maxTokens;
    _stopSequences = List.from(widget.stopSequences);
    _temperature = widget.temperature;
    _topK = widget.topK;
    _topP = widget.topP;
    _systemPrompt = widget.systemPrompt;

    _stopSequencesController.text = _stopSequences.join(', ');
    _systemPromptController.text = _systemPrompt;
  }

  @override
  void dispose() {
    _stopSequencesController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Row(
              children: [
                const Text(
                  'Advanced Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 區塊一｜生成控制

            // 最大生成長度
            _buildSliderSetting(
              title: 'Max Tokens',
              value: _maxTokens.toDouble(),
              min: 16,
              max: 2048,
              divisions: 127, // (2048-16)/16 = 127
              onChanged: (value) => setState(() => _maxTokens = value.toInt()),
              displayValue: '${_maxTokens} tokens',
            ),
            const SizedBox(height: 16),

            // 停止序列
            _buildTextFieldSetting(
              title: 'Stop Sequences',
              controller: _stopSequencesController,
              hintText: 'For example: </s>, ###, [END]',
              helperText: 'Separate multiple sequences with commas',
              maxLines: 2,
              onChanged: (value) {
                _stopSequences = value
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
              },
            ),
            const SizedBox(height: 24),

            // 區塊二｜取樣控制

            // 溫度
            _buildSliderSetting(
              title: 'Temperature',
              value: _temperature,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              onChanged: (value) => setState(() => _temperature = value),
              displayValue: _temperature.toStringAsFixed(1),
              helperText: 'Higher values make the output more random',
            ),
            const SizedBox(height: 16),

            // Top-K
            _buildSliderSetting(
              title: 'Top-K',
              value: _topK.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (value) => setState(() => _topK = value.toInt()),
              displayValue: _topK.toString(),
            ),
            const SizedBox(height: 16),

            // Top-P
            _buildSliderSetting(
              title: 'Top-P',
              value: _topP,
              min: 0.1,
              max: 1.0,
              divisions: 18, // (1.0-0.1)/0.05 = 18
              onChanged: (value) => setState(() => _topP = value),
              displayValue: _topP.toStringAsFixed(2),
            ),
            const SizedBox(height: 24),

            _buildTextFieldSetting(
              title: 'System Prompt',
              controller: _systemPromptController,
              hintText: 'Enter system role description...',
              helperText: 'This will be added before the user prompt',
              maxLines: 4,
              onChanged: (value) => _systemPrompt = value,
            ),
            const SizedBox(height: 32),

            // 底部操作按鈕
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _maxTokens = 256;
                        _stopSequences = [];
                        _temperature = 0.8;
                        _topK = 40;
                        _topP = 0.9;
                        _systemPrompt = '';
                        _stopSequencesController.text = '';
                        _systemPromptController.text = '';
                      });
                      widget.onReset();
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(
                        maxTokens: _maxTokens,
                        stopSequences: _stopSequences,
                        temperature: _temperature,
                        topK: _topK,
                        topP: _topP,
                        systemPrompt: _systemPrompt,
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String displayValue,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(displayValue, style: const TextStyle(color: Colors.blue)),
          ],
        ),
        if (helperText != null)
          Text(helperText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTextFieldSetting({
    required String title,
    required TextEditingController controller,
    required String hintText,
    String? helperText,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        if (helperText != null)
          Text(helperText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.all(12),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
