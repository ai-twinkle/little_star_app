import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/architecture_rules.dart';

void main() {
  final rules = ArchitectureRules(Directory.current);

  test('core does not depend on the UI layer', () {
    final violations = rules.coreUiDependencies();

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('feature services do not depend on the UI layer', () {
    final violations = rules.featureServiceUiDependencies();

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('data and platform code does not depend on the engine layer', () {
    final violations = rules.dataCoreDependencies();

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test(
    'benchmark and MLX model widgets do not own filesystem or runner dependencies',
    () {
      final violations = rules.benchmarkAndMlxWidgetDependencies();

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test('home widget does not own platform capability detection', () {
    final violations = rules.homeWidgetPlatformDependencies();

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
