import 'dart:math';

class SequenceFilter {
  final String sequence;
  StringBuffer buffer = StringBuffer();

  SequenceFilter(this.sequence);

  String? processChunk(String chunk) {
    for (var i = 0; i < chunk.length; i++) {
      String sub;
      if (buffer.isEmpty) {
        sub = chunk.substring(i);
      } else {
        final budget = min(sequence.length - buffer.length, chunk.length);
        sub = buffer.toString() + chunk.substring(0, budget);
      }

      if (sequence.contains(sub)) {
        buffer.write(sub);
        if (buffer.length == sequence.length) {
          buffer.clear();
        }
      } else {
        String result = chunk.substring(i);

        if (buffer.isNotEmpty) {
          result += buffer.toString();
          buffer.clear();
        }

        return result;
      }
    }
    return null;
  }
}

/// An enumeration representing different types of LLM Prompt Formats.
enum PromptFormatType {
  raw,
  chatml,
  alpaca,
}

/// A class representing a LLM Prompt Format.
abstract class PromptFormat {
  late List<SequenceFilter> _filters;
  final PromptFormatType type;
  final String inputSequence;
  final String outputSequence;
  final String systemSequence;
  final String? stopSequence;

  PromptFormat(this.type,
      {required this.inputSequence,
      required this.outputSequence,
      required this.systemSequence,
      this.stopSequence}) {
    var tempFilters = [
      SequenceFilter(inputSequence),
      SequenceFilter(outputSequence),
      SequenceFilter(systemSequence)
    ];

    if (stopSequence != null) {
      tempFilters.add(SequenceFilter(stopSequence!));
    }

    _filters = tempFilters;
  }

  String? filterResponse(String response) {
    // Iteratively process the response through each filter
    List<String?> chunks = [];
    for (var filter in _filters) {
      chunks.add(filter.processChunk(response));
    }

    // If any of the _filters return null, the response is incomplete
    for (var chunk in chunks) {
      if (chunk == null) return null;
    }

    // Return the longest chunk
    return chunks.reduce((a, b) => a!.length > b!.length ? a : b);
  }

  String formatPrompt(String prompt) {
    if (stopSequence != null) {
      return '$inputSequence$prompt$stopSequence$outputSequence';
    }
    return '$inputSequence$prompt$outputSequence';
  }

  String formatMessages(List<Map<String, dynamic>> messages) {
    String formattedMessages = '';
    for (var message in messages) {
      if (message['role'] == 'user') {
        formattedMessages += '$inputSequence${message['content']}';
      } else if (message['role'] == 'assistant') {
        formattedMessages += '$outputSequence${message['content']}';
      } else if (message['role'] == 'system') {
        formattedMessages += '$systemSequence${message['content']}';
      }

      if (stopSequence != null) {
        formattedMessages += stopSequence!;
      }
    }
    return formattedMessages;
  }
}