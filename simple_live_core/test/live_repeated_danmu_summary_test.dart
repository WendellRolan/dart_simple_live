import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('LiveRepeatedDanmuAggregator', () {
    test('hides repeated text below the minimum display count', () {
      final aggregator = LiveRepeatedDanmuAggregator();

      for (var i = 0; i < 9; i++) {
        aggregator.add('哈哈哈哈哈');
      }

      expect(aggregator.preview(), isEmpty);
    });

    test('shows the real repeated text once it reaches the minimum count', () {
      final aggregator = LiveRepeatedDanmuAggregator();

      for (var i = 0; i < 10; i++) {
        aggregator.add('哈哈哈哈哈');
      }

      final summaries = aggregator.preview();
      expect(summaries, hasLength(1));
      expect(summaries.single.text, '哈哈哈哈哈');
      expect(summaries.single.count, 10);
      expect(summaries.single.displayText, '哈哈哈哈哈 x10');
    });

    test('keeps only the two most repeated texts in each flush', () {
      final aggregator = LiveRepeatedDanmuAggregator();

      for (var i = 0; i < 30; i++) {
        aggregator.add('哈哈哈哈哈');
      }
      for (var i = 0; i < 20; i++) {
        aggregator.add('来了');
      }
      for (var i = 0; i < 10; i++) {
        aggregator.add('666');
      }

      final summaries = aggregator.drain();
      expect(summaries.map((item) => item.displayText), [
        '哈哈哈哈哈 x30',
        '来了 x20',
      ]);
      expect(aggregator.preview(), isEmpty);
    });
  });
}
