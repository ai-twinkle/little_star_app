import 'package:little_star_app/core/inference/sampling_params.dart';

/// Supported model file formats.
enum ModelFormat { gguf, mlx }

/// Hints the chat-template layer (task-301) about which template family to
/// apply when the GGUF's built-in template is absent or unrecognised.
enum ChatTemplateHint { gemma, llama3, qwen2, qwen3, unknown }

/// Preferred inference backend. [auto] lets [BackendSelector] decide based on
/// format and platform.
enum BackendHint { auto, llamaCpp, mlx }

/// Full description of a model: source, format, inference config, and UI metadata.
///
/// Used by [BackendSelector], [LlamaCppBackend], and the UI layer.
/// [localPath] is null until the model has been downloaded.
class ModelProfile {
  /// Unique app-level identifier (often mirrors [hfRepoId]).
  final String id;

  /// Human-readable name shown in the UI.
  final String displayName;

  final ModelFormat format;

  /// HuggingFace repository id, e.g. `"unsloth/gemma-3-270m-it-GGUF"`.
  /// Defaults to [id] when not provided.
  final String hfRepoId;

  /// Specific file to download from the repo, e.g. `"model-Q4_K_M.gguf"`.
  /// Null for MLX models (multi-file download handled separately in task-1003).
  final String? recommendedQuantization;

  /// Template family hint for [ChatTemplate] (task-301).
  final ChatTemplateHint chatTemplateHint;

  /// Context window length in tokens.
  final int ctxLen;

  /// Default sampling parameters for this model.
  final SamplingParams defaultSamplingParams;

  /// Preferred backend; [BackendHint.auto] defers to [BackendSelector].
  final BackendHint backendHint;

  // ── UI metadata ──────────────────────────────────────────────────────────

  final String? quickDescription;
  final List<String> useCases;
  final String? badge;

  // ── Local state ───────────────────────────────────────────────────────────

  /// Absolute path to the downloaded model file (or directory for MLX).
  /// Null when the model has not been downloaded yet.
  final String? localPath;

  const ModelProfile({
    required this.id,
    required this.displayName,
    required this.format,
    String? hfRepoId,
    this.recommendedQuantization,
    this.chatTemplateHint = ChatTemplateHint.unknown,
    this.ctxLen = 2048,
    this.defaultSamplingParams = const SamplingParams(),
    this.backendHint = BackendHint.auto,
    this.quickDescription,
    this.useCases = const [],
    this.badge,
    this.localPath,
  }) : hfRepoId = hfRepoId ?? id;

  ModelProfile copyWith({
    String? id,
    String? displayName,
    ModelFormat? format,
    String? hfRepoId,
    String? recommendedQuantization,
    ChatTemplateHint? chatTemplateHint,
    int? ctxLen,
    SamplingParams? defaultSamplingParams,
    BackendHint? backendHint,
    String? quickDescription,
    List<String>? useCases,
    String? badge,
    String? localPath,
    bool clearLocalPath = false,
  }) {
    return ModelProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      format: format ?? this.format,
      hfRepoId: hfRepoId ?? this.hfRepoId,
      recommendedQuantization: recommendedQuantization ?? this.recommendedQuantization,
      chatTemplateHint: chatTemplateHint ?? this.chatTemplateHint,
      ctxLen: ctxLen ?? this.ctxLen,
      defaultSamplingParams: defaultSamplingParams ?? this.defaultSamplingParams,
      backendHint: backendHint ?? this.backendHint,
      quickDescription: quickDescription ?? this.quickDescription,
      useCases: useCases ?? this.useCases,
      badge: badge ?? this.badge,
      localPath: clearLocalPath ? null : (localPath ?? this.localPath),
    );
  }

  // ── JSON ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'format': format.name,
        'hfRepoId': hfRepoId,
        if (recommendedQuantization != null)
          'recommendedQuantization': recommendedQuantization,
        'chatTemplateHint': chatTemplateHint.name,
        'ctxLen': ctxLen,
        'defaultSamplingParams': defaultSamplingParams.toJson(),
        'backendHint': backendHint.name,
        if (quickDescription != null) 'quickDescription': quickDescription,
        if (useCases.isNotEmpty) 'useCases': useCases,
        if (badge != null) 'badge': badge,
        if (localPath != null) 'localPath': localPath,
      };

  factory ModelProfile.fromJson(Map<String, dynamic> json) {
    return ModelProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      format: ModelFormat.values.byName(json['format'] as String),
      hfRepoId: json['hfRepoId'] as String?,
      recommendedQuantization: json['recommendedQuantization'] as String?,
      chatTemplateHint: ChatTemplateHint.values.byName(
        (json['chatTemplateHint'] as String?) ?? 'unknown',
      ),
      ctxLen: (json['ctxLen'] as num?)?.toInt() ?? 2048,
      defaultSamplingParams: json['defaultSamplingParams'] != null
          ? SamplingParams.fromJson(
              json['defaultSamplingParams'] as Map<String, dynamic>)
          : const SamplingParams(),
      backendHint: BackendHint.values.byName(
        (json['backendHint'] as String?) ?? 'auto',
      ),
      quickDescription: json['quickDescription'] as String?,
      useCases: (json['useCases'] as List<dynamic>?)?.cast<String>() ?? [],
      badge: json['badge'] as String?,
      localPath: json['localPath'] as String?,
    );
  }
}
