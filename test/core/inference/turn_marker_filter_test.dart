import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/turn_marker_filter.dart';

void main() {
  group('TurnMarkerFilter', () {
    test('passes through normal text with no marker', () {
      final filter = TurnMarkerFilter();
      final r1 = filter.feed('Hello');
      final r2 = filter.feed(' world');
      expect(r1.stop, isFalse);
      expect(r2.stop, isFalse);
      expect(r1.text + r2.text + filter.flush(), 'Hello world');
    });

    test('detects a complete marker in a single feed', () {
      final filter = TurnMarkerFilter();
      final r = filter.feed('Answer.<start_of_turn>user garbage');
      expect(r.stop, isTrue);
      expect(r.text, 'Answer.');
    });

    test('detects a marker split across multiple feeds', () {
      final filter = TurnMarkerFilter();
      final r1 = filter.feed('Answer text');
      final r2 = filter.feed('<start_of');
      final r3 = filter.feed('_turn>user');
      expect(r1.stop, isFalse);
      expect(r2.stop, isFalse);
      expect(r3.stop, isTrue);
      expect(r1.text + r2.text + r3.text, 'Answer text');
    });

    test('detects <|assistant|> marker', () {
      final filter = TurnMarkerFilter();
      final r = filter.feed('42.<|assistant|>fabricated');
      expect(r.stop, isTrue);
      expect(r.text, '42.');
    });

    test('holds back a tail that looks like the start of a marker', () {
      final filter = TurnMarkerFilter();
      final r = filter.feed('done<start_of');
      expect(r.stop, isFalse);
      expect(r.text, 'done');
    });

    test('flush emits held-back text that never completed a marker', () {
      final filter = TurnMarkerFilter();
      filter.feed('done<start_of');
      final rest = filter.flush();
      expect(rest, '<start_of');
    });

    test('a "<" that never grows into a marker is eventually released', () {
      final filter = TurnMarkerFilter();
      final r1 = filter.feed('done<');
      // trailing '<' is a prefix of every marker, so it's held back until
      // more text arrives to disambiguate.
      expect(r1.text, 'done');
      final r2 = filter.feed(' but not a marker');
      expect(r2.text, '< but not a marker');
      expect(r1.text + r2.text, 'done< but not a marker');
    });
  });
}
