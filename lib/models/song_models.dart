/// One modular lyric block ("Verse 1", "Chorus", …) holding the active line
/// set plus the alternate sets the rewriter cycles through.
class LyricSection {
  final String id;
  final String label;

  /// Alternate line sets; [variantIndex] selects the active one.
  final List<List<String>> variants;
  final int variantIndex;

  const LyricSection({
    required this.id,
    required this.label,
    required this.variants,
    this.variantIndex = 0,
  });

  /// The lines currently shown for this section.
  List<String> get lines =>
      variants[variantIndex.clamp(0, variants.length - 1)];

  LyricSection copyWith({int? variantIndex, List<List<String>>? variants}) {
    return LyricSection(
      id: id,
      label: label,
      variants: variants ?? this.variants,
      variantIndex: variantIndex ?? this.variantIndex,
    );
  }

  /// JSON round-trip used by the trip store so lyric drafts survive restarts.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'variants': variants,
      'variantIndex': variantIndex,
    };
  }

  factory LyricSection.fromJson(Map<String, dynamic> json) {
    return LyricSection(
      id: json['id'] as String,
      label: json['label'] as String,
      variants: <List<String>>[
        for (final List<dynamic> variant in json['variants'] as List<dynamic>)
          <String>[for (final dynamic line in variant) line as String],
      ],
      variantIndex: json['variantIndex'] as int? ?? 0,
    );
  }
}

/// A generated lyric draft: title plus the ordered modular sections.
class LyricSong {
  final String title;
  final List<LyricSection> sections;

  const LyricSong({required this.title, required this.sections});

  LyricSection? section(String id) {
    for (final LyricSection s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// A copy of this song with [updated] swapped in for [sectionId].
  LyricSong withSection(String sectionId, LyricSection updated) {
    return LyricSong(
      title: title,
      sections: [
        for (final LyricSection s in sections) s.id == sectionId ? updated : s,
      ],
    );
  }

  /// JSON round-trip used by the trip store so lyric drafts survive restarts.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'sections': <Map<String, dynamic>>[
        for (final LyricSection section in sections) section.toJson(),
      ],
    };
  }

  factory LyricSong.fromJson(Map<String, dynamic> json) {
    return LyricSong(
      title: json['title'] as String,
      sections: <LyricSection>[
        for (final Map<String, dynamic> section
            in json['sections'] as List<dynamic>)
          LyricSection.fromJson(section),
      ],
    );
  }
}

/// Result of a conversational refinement: the AI's acknowledgment plus the
/// updated song with the targeted section re-rolled.
class LyricistReply {
  final String reply;
  final LyricSong song;

  const LyricistReply({required this.reply, required this.song});
}

/// One bubble in the lyric chat transcript.
class ChatMessage {
  final bool fromMe;
  final String text;

  const ChatMessage({required this.fromMe, required this.text});
}

/// ── Vibe / style selection ─────────────────────────────────────────────────

/// A musical vibe card on the Choose Sound stage: what the song should sound
/// like and the tempo window the synth accepts for it.
class MusicalStyle {
  final String id;
  final String label;

  /// One-line preview pitch shown on the card.
  final String tagline;

  /// Short energy descriptor shown as card metadata.
  final String mood;
  final int defaultBpm;
  final int minBpm;
  final int maxBpm;

  const MusicalStyle({
    required this.id,
    required this.label,
    required this.tagline,
    required this.mood,
    required this.defaultBpm,
    required this.minBpm,
    required this.maxBpm,
  });

  /// The launch vibe catalog (issue #04: Pop-Punk, Euro-Trash Synth, …).
  static const List<MusicalStyle> catalog = <MusicalStyle>[
    MusicalStyle(
      id: 'pop-punk',
      label: 'Pop-Punk',
      tagline: 'Three chords, zero chill.',
      mood: 'Loud · fast · defiant',
      defaultBpm: 168,
      minBpm: 140,
      maxBpm: 190,
    ),
    MusicalStyle(
      id: 'euro-trash-synth',
      label: 'Euro-Trash Synth',
      tagline: 'Four-on-the-floor glitter and regret.',
      mood: 'Neon · driving · shameless',
      defaultBpm: 128,
      minBpm: 110,
      maxBpm: 140,
    ),
    MusicalStyle(
      id: 'sad-boy-indie',
      label: 'Sad Boy Indie',
      tagline: 'Guitars, feelings, one slow crescendo.',
      mood: 'Soft · wistful · sincere',
      defaultBpm: 92,
      minBpm: 70,
      maxBpm: 110,
    ),
    MusicalStyle(
      id: 'acoustic-road-folk',
      label: 'Acoustic Road Folk',
      tagline: 'Campfire strums for the long haul.',
      mood: 'Warm · unhurried · sing-along',
      defaultBpm: 104,
      minBpm: 80,
      maxBpm: 128,
    ),
    MusicalStyle(
      id: 'chaotic-rap',
      label: 'Chaotic Rap',
      tagline: 'No hook. All hooks. Good luck.',
      mood: 'Frantic · punchy · unserious',
      defaultBpm: 144,
      minBpm: 120,
      maxBpm: 170,
    ),
  ];
}

/// ── SongTimeline (canonical alignment JSON) ────────────────────────────────

/// Musical role of a timeline section (CONTEXT.md: intro, verse, chorus,
/// drop, outro — plus the lyricist's bridge).
enum TimelineSectionKind { intro, verse, chorus, bridge, drop, outro }

/// What kind of evidence popup a cue triggers.
enum EvidenceCueKind { photo, sticker }

/// One word of the vocal with millisecond-accurate span and syllable count
/// — the kinetic-subtitle tick marker. Syllable-level timing derives
/// uniformly by splitting the word's span across [syllables].
class TimelineWord {
  final String word;
  final int startMs;
  final int endMs;
  final int syllables;

  const TimelineWord({
    required this.word,
    required this.startMs,
    required this.endMs,
    required this.syllables,
  });
}

/// One lyric line within a section, spanning its word timeline.
class TimelineLine {
  final String text;
  final int startMs;
  final int endMs;
  final List<TimelineWord> words;

  const TimelineLine({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.words,
  });
}

/// A musical section (intro / verse / chorus / …) of the aligned song.
class TimelineSection {
  final String id;
  final String label;
  final TimelineSectionKind kind;
  final int startMs;
  final int endMs;
  final List<TimelineLine> lines;

  const TimelineSection({
    required this.id,
    required this.label,
    required this.kind,
    required this.startMs,
    required this.endMs,
    required this.lines,
  });
}

/// Beat grid derived from the song tempo: beat interval, beats per bar and
/// the absolute window the grid spans. Downbeats are every [beatsPerBar]-th
/// beat starting at [offsetMs].
class DownbeatGrid {
  final double beatIntervalMs;
  final int beatsPerBar;
  final int offsetMs;
  final int durationMs;

  const DownbeatGrid({
    required this.beatIntervalMs,
    required this.beatsPerBar,
    required this.offsetMs,
    required this.durationMs,
  });

  /// Every beat time in [offsetMs, durationMs).
  List<double> get beatTimes => <double>[
    for (int i = 0; offsetMs + i * beatIntervalMs < durationMs; i++)
      offsetMs + i * beatIntervalMs,
  ];

  /// First beat of every bar.
  List<double> get downbeatTimes {
    final List<double> beats = beatTimes;
    final int step = beatsPerBar < 1 ? 1 : beatsPerBar;
    return <double>[for (int i = 0; i < beats.length; i += step) beats[i]];
  }
}

/// An evidence popup scheduled at a vocal moment: the trip photo or sticker
/// that should fly in while a keyword line lands.
class EvidenceCue {
  final int timeMs;
  final EvidenceCueKind kind;
  final String label;
  final String memoryId;

  const EvidenceCue({
    required this.timeMs,
    required this.kind,
    required this.label,
    required this.memoryId,
  });
}

/// Canonical alignment document for a synthesized song: word/syllable
/// timestamps per line, section spans, the downbeat grid and evidence cues.
class SongTimeline {
  /// Schema version accepted/emitted by [fromJson]/[toJson].
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String title;
  final String styleId;
  final int bpm;
  final int durationMs;
  final DownbeatGrid downbeat;
  final List<TimelineSection> sections;
  final List<EvidenceCue> cues;

  const SongTimeline({
    this.schemaVersion = currentSchemaVersion,
    required this.title,
    required this.styleId,
    required this.bpm,
    required this.durationMs,
    required this.downbeat,
    required this.sections,
    this.cues = const <EvidenceCue>[],
  });

  /// Total number of aligned word markers (kinetic-subtitle ticks).
  int get wordCount => <int>[
    for (final TimelineSection s in sections)
      for (final TimelineLine l in s.lines) l.words.length,
  ].fold(0, (int a, int b) => a + b);

  /// A copy of this timeline with [cues] swapped in.
  SongTimeline withCues(List<EvidenceCue> cues) {
    return SongTimeline(
      schemaVersion: schemaVersion,
      title: title,
      styleId: styleId,
      bpm: bpm,
      durationMs: durationMs,
      downbeat: downbeat,
      sections: sections,
      cues: cues,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'title': title,
      'styleId': styleId,
      'bpm': bpm,
      'durationMs': durationMs,
      'downbeat': <String, dynamic>{
        'beatIntervalMs': downbeat.beatIntervalMs,
        'beatsPerBar': downbeat.beatsPerBar,
        'offsetMs': downbeat.offsetMs,
        'durationMs': downbeat.durationMs,
      },
      'sections': <Map<String, dynamic>>[
        for (final TimelineSection s in sections)
          <String, dynamic>{
            'id': s.id,
            'label': s.label,
            'kind': s.kind.name,
            'startMs': s.startMs,
            'endMs': s.endMs,
            'lines': <Map<String, dynamic>>[
              for (final TimelineLine l in s.lines)
                <String, dynamic>{
                  'text': l.text,
                  'startMs': l.startMs,
                  'endMs': l.endMs,
                  'words': <Map<String, dynamic>>[
                    for (final TimelineWord w in l.words)
                      <String, dynamic>{
                        'word': w.word,
                        'startMs': w.startMs,
                        'endMs': w.endMs,
                        'syllables': w.syllables,
                      },
                  ],
                },
            ],
          },
      ],
      'cues': <Map<String, dynamic>>[
        for (final EvidenceCue c in cues)
          <String, dynamic>{
            'timeMs': c.timeMs,
            'kind': c.kind.name,
            'label': c.label,
            'memoryId': c.memoryId,
          },
      ],
    };
  }

  /// Strict parser for the canonical schema: every key is required, times are
  /// non-negative, spans must nest (words within lines within sections),
  /// siblings never overlap (sections, lines and words each arrive in time
  /// order), and kinds must be known. Anything else throws [FormatException]
  /// so malformed alignment data fails loudly.
  factory SongTimeline.fromJson(Map<String, dynamic> json) {
    void require(bool ok, String what) {
      if (!ok) throw FormatException('Invalid SongTimeline JSON: $what');
    }

    int intOf(Map<String, dynamic> map, String key, String what) {
      final Object? value = map[key];
      require(value is num, '$what.$key must be a number');
      return (value as num).toInt();
    }

    String stringOf(Map<String, dynamic> map, String key, String what) {
      final Object? value = map[key];
      require(value is String, '$what.$key must be a string');
      return value as String;
    }

    double doubleOf(Map<String, dynamic> map, String key, String what) {
      final Object? value = map[key];
      require(value is num, '$what.$key must be a number');
      return (value as num).toDouble();
    }

    Map<String, dynamic> mapOf(Object? value, String what) {
      require(value is Map<String, dynamic>, '$what must be an object');
      return value as Map<String, dynamic>;
    }

    List<Map<String, dynamic>> listOf(Object? value, String what) {
      require(value is List<Object?>, '$what must be an array');
      return <Map<String, dynamic>>[
        for (final Object? item in value as List<Object?>)
          mapOf(item, '$what[]'),
      ];
    }

    final int schemaVersion = intOf(json, 'schemaVersion', 'timeline');
    require(
      schemaVersion == currentSchemaVersion,
      'unsupported schemaVersion $schemaVersion (want $currentSchemaVersion)',
    );

    final int bpm = intOf(json, 'bpm', 'timeline');
    require(bpm > 0, 'bpm must be positive');

    final Map<String, dynamic> downbeatJson = mapOf(
      json['downbeat'],
      'timeline.downbeat',
    );
    final double beatIntervalMs = doubleOf(
      downbeatJson,
      'beatIntervalMs',
      'timeline.downbeat',
    );
    require(beatIntervalMs > 0, 'downbeat.beatIntervalMs must be positive');
    final int beatsPerBar = intOf(
      downbeatJson,
      'beatsPerBar',
      'timeline.downbeat',
    );
    require(beatsPerBar > 0, 'downbeat.beatsPerBar must be positive');

    final List<TimelineSection> sections = <TimelineSection>[];
    int previousEnd = -1;
    for (final Map<String, dynamic> sectionJson in listOf(
      json['sections'],
      'timeline.sections',
    )) {
      final String what = 'timeline.section[${sections.length}]';
      final String kindRaw = stringOf(sectionJson, 'kind', what);
      final TimelineSectionKind? kind = TimelineSectionKind.values
          .where((TimelineSectionKind k) => k.name == kindRaw)
          .firstOrNull;
      require(
        kind != null,
        '$what.kind "$kindRaw" is not a known section kind',
      );

      final int startMs = intOf(sectionJson, 'startMs', what);
      final int endMs = intOf(sectionJson, 'endMs', what);
      require(startMs >= 0, '$what.startMs must be non-negative');
      require(endMs >= startMs, '$what must not end before it starts');
      require(startMs >= previousEnd, '$what overlaps the previous section');
      previousEnd = endMs;

      final List<TimelineLine> lines = <TimelineLine>[];
      int previousLineEnd = -1;
      for (final Map<String, dynamic> lineJson in listOf(
        sectionJson['lines'],
        '$what.lines',
      )) {
        final String lineWhat = '$what.line[${lines.length}]';
        final int lineStart = intOf(lineJson, 'startMs', lineWhat);
        final int lineEnd = intOf(lineJson, 'endMs', lineWhat);
        require(
          lineStart >= startMs && lineEnd <= endMs && lineEnd >= lineStart,
          '$lineWhat must sit inside its section span',
        );
        require(
          lineStart >= previousLineEnd,
          '$lineWhat overlaps the previous line',
        );
        previousLineEnd = lineEnd;

        final List<TimelineWord> words = <TimelineWord>[];
        int previousWordEnd = -1;
        for (final Map<String, dynamic> wordJson in listOf(
          lineJson['words'],
          '$lineWhat.words',
        )) {
          final String wordWhat = '$lineWhat.word[${words.length}]';
          final int wordStart = intOf(wordJson, 'startMs', wordWhat);
          final int wordEnd = intOf(wordJson, 'endMs', wordWhat);
          require(wordStart >= 0, '$wordWhat.startMs must be non-negative');
          require(
            wordEnd >= wordStart,
            '$wordWhat must not end before it starts',
          );
          require(
            wordStart >= lineStart && wordEnd <= lineEnd,
            '$wordWhat must sit inside its line span',
          );
          require(
            wordStart >= previousWordEnd,
            '$wordWhat overlaps the previous word',
          );
          previousWordEnd = wordEnd;
          words.add(
            TimelineWord(
              word: stringOf(wordJson, 'word', wordWhat),
              startMs: wordStart,
              endMs: wordEnd,
              syllables: intOf(wordJson, 'syllables', wordWhat),
            ),
          );
        }
        lines.add(
          TimelineLine(
            text: stringOf(lineJson, 'text', lineWhat),
            startMs: lineStart,
            endMs: lineEnd,
            words: words,
          ),
        );
      }
      sections.add(
        TimelineSection(
          id: stringOf(sectionJson, 'id', what),
          label: stringOf(sectionJson, 'label', what),
          kind: kind!,
          startMs: startMs,
          endMs: endMs,
          lines: lines,
        ),
      );
    }

    final List<EvidenceCue> cues = <EvidenceCue>[];
    for (final Map<String, dynamic> cueJson in listOf(
      json['cues'],
      'timeline.cues',
    )) {
      final String what = 'timeline.cue[${cues.length}]';
      final int timeMs = intOf(cueJson, 'timeMs', what);
      require(timeMs >= 0, '$what.timeMs must be non-negative');
      final String kindRaw = stringOf(cueJson, 'kind', what);
      final EvidenceCueKind? kind = EvidenceCueKind.values
          .where((EvidenceCueKind k) => k.name == kindRaw)
          .firstOrNull;
      require(kind != null, '$what.kind "$kindRaw" is not a known cue kind');
      cues.add(
        EvidenceCue(
          timeMs: timeMs,
          kind: kind!,
          label: stringOf(cueJson, 'label', what),
          memoryId: stringOf(cueJson, 'memoryId', what),
        ),
      );
    }

    return SongTimeline(
      schemaVersion: schemaVersion,
      title: stringOf(json, 'title', 'timeline'),
      styleId: stringOf(json, 'styleId', 'timeline'),
      bpm: bpm,
      durationMs: intOf(json, 'durationMs', 'timeline'),
      downbeat: DownbeatGrid(
        beatIntervalMs: beatIntervalMs,
        beatsPerBar: beatsPerBar,
        offsetMs: intOf(downbeatJson, 'offsetMs', 'timeline.downbeat'),
        durationMs: intOf(downbeatJson, 'durationMs', 'timeline.downbeat'),
      ),
      sections: sections,
      cues: cues,
    );
  }
}
