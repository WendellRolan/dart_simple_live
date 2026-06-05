class LiveRepeatedDanmuSummary {
  final String text;
  final int count;

  const LiveRepeatedDanmuSummary({required this.text, required this.count});

  String get displayText => "$text x$count";
}

class LiveRepeatedDanmuAggregator {
  final int minDisplayCount;
  final int maxDisplayItems;
  final _counters = <String, _RepeatedDanmuCounter>{};
  int _sequence = 0;

  LiveRepeatedDanmuAggregator({
    this.minDisplayCount = 10,
    this.maxDisplayItems = 2,
  }) : assert(minDisplayCount > 0),
       assert(maxDisplayItems > 0);

  void add(String text) {
    final value = _normalizeText(text);
    if (value.isEmpty) {
      return;
    }
    final counter = _counters[value];
    if (counter == null) {
      _counters[value] = _RepeatedDanmuCounter(
        text: value,
        count: 1,
        sequence: _sequence++,
      );
    } else {
      counter.count += 1;
    }
  }

  List<LiveRepeatedDanmuSummary> drain() {
    final result = _buildSummaries();
    clear();
    return result;
  }

  List<LiveRepeatedDanmuSummary> preview() {
    return _buildSummaries();
  }

  void clear() {
    _counters.clear();
    _sequence = 0;
  }

  List<LiveRepeatedDanmuSummary> _buildSummaries() {
    final counters =
        _counters.values.where((item) => item.count >= minDisplayCount).toList()
          ..sort((a, b) {
            final countCompare = b.count.compareTo(a.count);
            if (countCompare != 0) {
              return countCompare;
            }
            return a.sequence.compareTo(b.sequence);
          });
    return counters
        .take(maxDisplayItems)
        .map(
          (item) =>
              LiveRepeatedDanmuSummary(text: item.text, count: item.count),
        )
        .toList();
  }

  String _normalizeText(String text) {
    return text.trim().replaceAll(RegExp(r"\s+"), " ");
  }
}

class _RepeatedDanmuCounter {
  final String text;
  int count;
  final int sequence;

  _RepeatedDanmuCounter({
    required this.text,
    required this.count,
    required this.sequence,
  });
}
