import 'package:dio/dio.dart';
import 'package:little_star_app/data/services/huggingface_service.dart';
import 'package:little_star_app/models/hf_model_info.dart';

/// Lists and downloads the files of an MLX model repo on Hugging Face.
///
/// Abstracted from [MlxModelViewModel] (behind an interface, mirroring
/// [MlxChannelDriver]/`LlamaFfiDriver`) purely so the view model's download
/// orchestration logic can be unit-tested without real network calls.
abstract class MlxRepoFetcher {
  Future<List<HFModelFile>> listFiles(String repoId);

  Future<void> download(
    String url,
    String destinationPath, {
    void Function(int received, int total)? onProgress,
  });
}

class HttpMlxRepoFetcher implements MlxRepoFetcher {
  final HuggingFaceService _hfService;
  final Dio _dio;

  HttpMlxRepoFetcher({HuggingFaceService? hfService, Dio? dio})
      : _hfService = hfService ?? HuggingFaceService(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 30),
            ));

  @override
  Future<List<HFModelFile>> listFiles(String repoId) =>
      _hfService.getMlxModelFiles(repoId);

  @override
  Future<void> download(
    String url,
    String destinationPath, {
    void Function(int received, int total)? onProgress,
  }) {
    return _dio.download(url, destinationPath, onReceiveProgress: onProgress);
  }
}
