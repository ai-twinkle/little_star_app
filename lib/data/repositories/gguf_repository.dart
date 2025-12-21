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
    final List<GGUFModelInfo> models = [];

    try {
      // Scan the dedicated models directory
      final modelsDir = await directoryService.getModelsDirectory();

      if (await modelsDir.exists()) {
        await for (final entity in modelsDir.list()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
            final stat = await entity.stat();
            final fileName = entity.path.split('/').last;
            models.add(GGUFModelInfo(
              filePath: entity.path,
              fileName: fileName,
              fileSize: stat.size,
            ));
          }
        }
      }
    } catch (e) {
      // Return empty list on error - caller can check if list is empty
      // Error will be visible in the UI as "No GGUF files found"
    }

    return models;
  }
}