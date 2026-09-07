import '../models/song_models.dart';
import '../models/trip_models.dart';

/// CONTEXT.md evidence-cue seam: maps lyric keywords to the trip photos and
/// stickers that should pop up while their line is sung.
abstract class EvidenceCueEngine {
  Future<List<EvidenceCue>> cues({
    required SongTimeline timeline,
    required List<TimelineMemory> memories,
  });
}

/// Deterministic keyword matcher: builds a keyword set per memory from its
/// location, caption and text, then fires one cue per memory at the earliest
/// aligned word that sings one of its keywords. Memories with a photo pop up
/// as photo cues; the rest become stickers.
class KeywordEvidenceCueEngine implements EvidenceCueEngine {
  const KeywordEvidenceCueEngine();

  /// Keywords shorter than this are too generic to cue on.
  static const int _minKeywordLength = 4;

  /// Longest cue label before truncation on a word boundary.
  static const int _maxLabelLength = 40;

  /// Function words and generic narrative verbs that must never become
  /// keywords — otherwise "with" in a memory text would cue every lyric
  /// line containing "with".
  static const Set<String> _stopwords = <String>{
    'that', 'this', 'these', 'those', 'with', 'from', 'into', 'onto', //
    'over', 'under', 'then', 'than', 'they', 'them', 'their', 'there', //
    'here', 'were', 'have', 'been', 'being', 'will', 'would', 'could', //
    'should', 'must', 'might', 'shall', 'about', 'after', 'before', //
    'while', 'where', 'which', 'when', 'what', 'just', 'some', 'much', //
    'many', 'more', 'most', 'very', 'such', 'also', 'only', 'even', //
    'your', 'ours', 'because', 'until', 'again', 'once', 'each', 'both', //
    'every', 'ever', 'still', 'went', 'come', 'came', 'take', 'took', //
    'made', 'make', 'said', 'told', 'tell', 'want', 'like', 'got',
  };

  @override
  Future<List<EvidenceCue>> cues({
    required SongTimeline timeline,
    required List<TimelineMemory> memories,
  }) async {
    // Words in vocal order; sections/lines/words are walked in time order.
    final List<TimelineWord> words = <TimelineWord>[
      for (final TimelineSection section in timeline.sections)
        for (final TimelineLine line in section.lines) ...line.words,
    ];

    final List<EvidenceCue> cues = <EvidenceCue>[];
    for (final TimelineMemory memory in memories) {
      final Set<String> keywords = _keywordsFor(memory);
      if (keywords.isEmpty) continue;
      for (final TimelineWord word in words) {
        if (!keywords.contains(_normalize(word.word))) continue;
        cues.add(
          EvidenceCue(
            timeMs: word.startMs,
            kind: memory.hasPhoto
                ? EvidenceCueKind.photo
                : EvidenceCueKind.sticker,
            label: _labelFor(memory),
            memoryId: memory.id,
          ),
        );
        break; // one cue per memory: the first sung occurrence wins
      }
    }
    cues.sort((EvidenceCue a, EvidenceCue b) => a.timeMs.compareTo(b.timeMs));
    return cues;
  }

  /// Searchable keywords of a memory: location, caption and note tokens.
  Set<String> _keywordsFor(TimelineMemory memory) {
    final Set<String> keywords = <String>{};
    final List<String> sources = <String>[
      if (memory.locationName != null) memory.locationName!,
      if (memory.photoCaption != null) memory.photoCaption!,
      memory.text,
    ];
    for (final String source in sources) {
      for (final String token in source.toLowerCase().split(
        RegExp(r'[^a-z0-9]+'),
      )) {
        if (token.length < _minKeywordLength || _stopwords.contains(token)) {
          continue;
        }
        keywords.add(token);
      }
    }
    return keywords;
  }

  String _normalize(String word) =>
      word.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  /// Most specific label available: pinned place, else caption, else note.
  String _labelFor(TimelineMemory memory) {
    final String raw = _firstNonEmpty(<String?>[
      memory.locationName?.trim(),
      memory.photoCaption?.trim(),
      memory.text.trim(),
    ]);
    if (raw.length <= _maxLabelLength) return raw;
    String cut = raw.substring(0, _maxLabelLength);
    final int lastSpace = cut.lastIndexOf(' ');
    if (lastSpace > 0) cut = cut.substring(0, lastSpace);
    return '$cut…';
  }

  String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }
}
