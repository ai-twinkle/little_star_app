import 'dart:io';

import 'package:flutter/material.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/models/gguf_model_info.dart';


class GGUFRepository {
  final DirectoryService directoryService;

  GGUFRepository({required this.directoryService});

  Future<bool> ensurePermissions(BuildContext context) async {
    return await directoryService.requestPermissions(context: context);
  }

  Future<List<GGUFModelInfo>> getGGUFModels() async {
    final List<String> filePaths;

    if (Platform.isAndroid || Platform.isIOS) {
      filePaths = await directoryService.findFiles(
        directoryTypes: [
          DirectoryType.documents,
          DirectoryType.downloads,
          DirectoryType.applicationSupport,
          DirectoryType.temporary,
        ],
        extension: '.gguf',
      );
    } else {
      // Desktop: scan current working directory
      filePaths = await directoryService.findFiles(directoryTypes: [DirectoryType.other], extension: '.gguf');
    }

    // Convert file paths to GGUFModelInfo objects and deduplicate
    final Map<String, GGUFModelInfo> modelsMap = {};

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        final fileName = file.uri.pathSegments.last;
        final modelInfo = GGUFModelInfo(
          filePath: filePath,
          fileName: fileName,
          fileSize: stat.size,
        );
        modelsMap[fileName] = modelInfo; // Deduplicate by filename
      }
    }

    return modelsMap.values.toList();
  }
}