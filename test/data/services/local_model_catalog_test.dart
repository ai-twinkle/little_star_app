import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/data/services/local_model_catalog.dart';

void main() {
  test('discover returns GGUF files and MLX snapshot directories', () async {
    final root = await Directory.systemTemp.createTemp(
      'local_model_catalog_test',
    );
    addTearDown(() => root.delete(recursive: true));
    final ggufRoot = Directory('${root.path}/gguf')..createSync();
    final mlxRoot = Directory('${root.path}/mlx')..createSync();
    File('${ggufRoot.path}/t1.gguf').writeAsStringSync('model');
    File('${ggufRoot.path}/ignore.txt').writeAsStringSync('not a model');
    Directory('${mlxRoot.path}/t1-mlx').createSync();

    final catalog = LocalModelCatalog.fixed(
      ggufRoot: ggufRoot,
      mlxRoot: mlxRoot,
    );

    final models = await catalog.discover();

    expect(models, hasLength(2));
    expect(models[0].label, 'GGUF · t1.gguf');
    expect(models[1].label, 'MLX · t1-mlx');
  });
}
