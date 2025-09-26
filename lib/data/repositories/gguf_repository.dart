import 'package:little_star_app/data/services/directory_service.dart';


class GGUFRepository {
  final DirectoryService directoryService;

  GGUFRepository({required this.directoryService});

  Future<List<String>> getGGUFFiles() async {
    return await directoryService.findFiles(directoryTypes: [DirectoryType.documents, DirectoryType.downloads], extension: '.gguf');
  }
}