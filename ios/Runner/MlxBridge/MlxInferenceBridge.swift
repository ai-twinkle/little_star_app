// MLX Inference Bridge — iOS implementation (mlx-swift-lm 3.31.3 API)
//
// SPM packages (added via Xcode → Runner project → Package Dependencies):
//   mlx-swift-lm  3.31.3   → products: MLXLLM, MLXLMCommon, MLXHuggingFace
//   swift-transformers      → products: Tokenizers
//
// Linked to Runner target: MLXLLM, MLXLMCommon, MLXHuggingFace, Tokenizers

import Foundation
import MLXLLM
import MLXLMCommon
import Tokenizers   // from swift-transformers (provides AutoTokenizer)

// MARK: - Macro-free tokenizer loader

/// Wraps swift-transformers AutoTokenizer to conform to MLXLMCommon.TokenizerLoader.
/// This avoids the MLXHuggingFaceMacros trust requirement.
private struct AutoTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await AutoTokenizer.from(modelFolder: directory)
        return TransformersTokenizerBridge(upstream)
    }
}

private struct TransformersTokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) { self.upstream = upstream }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

// MARK: - Token stream handler

final class MlxTokenStreamHandler: OnTokenStreamHandler {
    private(set) var currentSink: PigeonEventSink<MlxTokenEvent>?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MlxTokenEvent>) {
        currentSink = sink
    }

    override func onCancel(withArguments arguments: Any?) {
        currentSink = nil
    }

    func emit(_ event: MlxTokenEvent) {
        currentSink?.success(event)
    }

    func endStream() {
        currentSink?.endOfStream()
    }
}

// MARK: - Host API implementation

/// Implements MlxInferenceHostApi (Pigeon-generated protocol).
/// Lifecycle: loadModel → startGeneration (repeat) → disposeModel.
@MainActor
final class MlxInferenceBridge: MlxInferenceHostApi {

    private var modelContainer: ModelContainer?
    private var generationTask: Task<Void, Error>?

    /// Identifies which `startGeneration` call currently owns `generationTask`, so a task
    /// that clears it early (see the `.info` case below) can't stomp on a *different*,
    /// already-started generation if a new one began in between.
    private var generationEpoch = 0

    var streamHandler: MlxTokenStreamHandler?

    // MARK: MlxInferenceHostApi

    func loadModel(localPath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let url = URL(fileURLWithPath: localPath)
                self.modelContainer = try await LLMModelFactory.shared.loadContainer(
                    from: url,
                    using: AutoTokenizerLoader()
                )
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func startGeneration(messages: [MlxChatMessage], params: MlxGenerationParams) throws {
        guard let container = modelContainer else {
            throw PigeonError(
                code: "no-model", message: "No model loaded. Call loadModel first.", details: nil)
        }
        guard generationTask == nil else {
            throw PigeonError(
                code: "busy", message: "Generation already in progress.", details: nil)
        }

        generationEpoch += 1
        let myEpoch = generationEpoch

        generationTask = Task { [weak self] in
            // Safety net for the cancel/error paths, where .info (below) never fires.
            // Guarded by epoch — see the property doc comment — so this can't clear a
            // *different*, already-started generation's task reference.
            defer {
                if self?.generationEpoch == myEpoch { self?.generationTask = nil }
            }

            // Convert Pigeon messages → mlx-swift-lm Chat.Message
            let chatMessages: [Chat.Message] = messages.compactMap { msg in
                guard let role = Chat.Message.Role(rawValue: msg.role) else { return nil }
                return Chat.Message(role: role, content: msg.content)
            }

            let generateParams = GenerateParameters(
                maxTokens: Int(params.maxTokens),
                temperature: Float(params.temperature),
                topP: Float(params.topP)
            )

            let lmInput = try await container.prepare(input: UserInput(chat: chatMessages))
            let stream = try await container.generate(input: lmInput, parameters: generateParams)

            for await generation in stream {
                if Task.isCancelled { break }
                switch generation {
                case .chunk(let text):
                    self?.streamHandler?.emit(
                        MlxTokenEvent(token: text, isDone: false, tokensPerSecond: nil))
                case .info(let info):
                    // Clear *before* emitting isDone, not after this loop naturally exits —
                    // Dart's consumer treats isDone as the end-of-generation signal and, on
                    // the benchmark harness's back-to-back cold/warm calls, could otherwise
                    // start the next generation before this task's `for await` loop noticed
                    // the underlying AsyncStream had finished, hitting the "busy" guard above
                    // even though playback had, from Dart's perspective, already completed.
                    if self?.generationEpoch == myEpoch { self?.generationTask = nil }
                    self?.streamHandler?.emit(
                        MlxTokenEvent(token: "", isDone: true,
                                      tokensPerSecond: info.tokensPerSecond))
                case .toolCall:
                    break
                }
            }
        }
    }

    func cancelGeneration() throws {
        generationTask?.cancel()
        generationTask = nil
    }

    func disposeModel() throws {
        generationTask?.cancel()
        generationTask = nil
        modelContainer = nil
    }

    func isModelLoaded() throws -> Bool {
        return modelContainer != nil
    }
}
