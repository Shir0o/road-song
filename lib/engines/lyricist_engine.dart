import '../models/song_models.dart';
import '../models/trip_models.dart';

/// CONTEXT.md "Lyricist" engine seam: turns a trip's narrative (memories,
/// participants, name) into editable modular lyrics. v1 ships the
/// deterministic [TemplateLyricist]; a real LLM service can replace this
/// implementation without touching the UI.
abstract class LyricistEngine {
  /// Reads the trip and drafts a song: title plus the six modular sections.
  Future<LyricSong> composeSong({
    required String tripName,
    required List<String> participants,
    required List<TimelineMemory> memories,
  });

  /// Re-rolls [section] to its next alternate line set.
  Future<LyricSection> rewriteSection(LyricSection section);

  /// Maps free-form chat feedback to a section, re-rolls it, and returns the
  /// acknowledgment plus the updated song.
  Future<LyricistReply> respondToFeedback({
    required String feedback,
    required LyricSong song,
  });
}

/// Deterministic template composer: trip name, participants, memory moments
/// and pinned places are interpolated into fixed verse/chorus templates.
/// Same input always yields the same song, so the simulation is testable.
class TemplateLyricist implements LyricistEngine {
  const TemplateLyricist();

  static const List<String> sectionIds = [
    'intro',
    'v1',
    'ch',
    'v2',
    'br',
    'out',
  ];
  static const List<String> sectionLabels = [
    'Intro',
    'Verse 1',
    'Chorus',
    'Verse 2',
    'Bridge',
    'Outro',
  ];

  /// Longest memory snippet quoted inside a lyric line.
  static const int _maxSnippetLength = 64;

  @override
  Future<LyricSong> composeSong({
    required String tripName,
    required List<String> participants,
    required List<TimelineMemory> memories,
  }) async {
    final String trip = tripName.trim().isEmpty ? 'the trip' : tripName.trim();
    final List<String> names = _cleanNames(participants);
    final String who = _joinNames(names);
    final List<String> moments = [
      for (final TimelineMemory m in memories)
        if (m.text.trim().isNotEmpty) _snippet(m.text),
    ];
    final List<String> places = _placesOf(memories);

    final String firstPlace = places.isEmpty ? trip : places.first;
    final String lastPlace = places.length < 2 ? firstPlace : places.last;
    final bool onePlace = firstPlace == lastPlace;

    final String name1 = names.first;
    final String name2 = names.length > 1 ? names[1] : names.first;
    final String? moment1 = moments.isNotEmpty ? moments.first : null;
    final String? moment2 = moments.length > 1 ? moments[1] : null;
    final String? lastMoment = moments.isNotEmpty ? moments.last : null;

    final List<LyricSection> sections = [
      const LyricSection(
        id: 'intro',
        label: 'Intro',
        variants: [
          [
            "__TRIP__, as told by __WHO__,",
            'scrapbook open, tape rolling —',
            'every wrong turn, kept forever.',
          ],
          [
            "Press play on __TRIP__:",
            'the notes are messy, the company is good,',
            "this one's for the group chat.",
          ],
        ],
      ),
      LyricSection(
        id: 'v1',
        label: 'Verse 1',
        variants: [
          [
            "It started in __FIRST_PLACE__,",
            moment1 ?? 'Nobody checked the map, nobody cared,',
            "__NAME1__ swears it went differently —",
            'The tape says otherwise, friend.',
          ],
          [
            "Day one, __FIRST_PLACE__. The plan:",
            moment1 ?? 'We followed the loudest opinion,',
            "And __NAME1__ led us confidently the wrong way —",
            'Honestly? A strong start.',
          ],
        ],
      ),
      LyricSection(
        id: 'ch',
        label: 'Chorus',
        variants: [
          [
            "Sing it back on the long road through __TRIP__,",
            'every wrong turn worth the detour,',
            onePlace
                ? "round and round __FIRST_PLACE__, we held the line,"
                : "from __FIRST_PLACE__ to __LAST_PLACE__, we held the line,",
            "this one's ours forevermore.",
          ],
          [
            "Sing it louder on the road through __TRIP__,",
            'GPS crying "please turn around" —',
            onePlace
                ? "round and round __FIRST_PLACE__, we got lost,"
                : "from __FIRST_PLACE__ to __LAST_PLACE__ we got lost,",
            'but look what we found.',
          ],
        ],
      ),
      LyricSection(
        id: 'v2',
        label: 'Verse 2',
        variants: [
          [
            'By mid-trip the lore was thickening:',
            moment2 ?? 'Everyone had a system by then,',
            "And __NAME2__ said it couldn't get worse —",
            'It got worse. We have photos.',
          ],
          [
            'Somewhere around the halfway mark,',
            moment2 ?? 'The snacks ran out, the stories did not,',
            "We swore we'd do better tomorrow —",
            'We did not. Iconic.',
          ],
        ],
      ),
      LyricSection(
        id: 'br',
        label: 'Bridge',
        variants: [
          [
            lastMoment != null
                ? "And then — __LAST_MOMENT__ —"
                : 'And then the quiet part happened,',
            'nobody said much at all,',
            "__NAME1__ broke the silence:",
            '"...yeah." Some things don\'t need words.',
          ],
          [
            lastMoment != null
                ? "__LAST_MOMENT__ —"
                : 'The loudest day ended in quiet,',
            'we let the silence hold it,',
            "__NAME2__ tried to take a photo,",
            'Some moments refuse to fit the frame.',
          ],
        ],
      ),
      LyricSection(
        id: 'out',
        label: 'Outro',
        variants: [
          [
            "So here's to __TRIP__,",
            "to __WHO__,",
            'press play, and remember it all —',
            'every wrong turn, kept forever.',
          ],
          [
            'One last chorus for the road,',
            "for __WHO__ and the ones who missed it,",
            "__TRIP__, we'll be back for you —",
            'till then, the tape keeps rolling.',
          ],
        ],
      ),
    ];

    final Map<String, String> slots = {
      "__TRIP__": trip,
      "__WHO__": who,
      "__FIRST_PLACE__": firstPlace,
      "__LAST_PLACE__": lastPlace,
      "__NAME1__": name1,
      "__NAME2__": name2,
      "__LAST_MOMENT__": lastMoment ?? '',
    };

    List<String> fill(List<String> lines) => [
      for (final String line in lines)
        slots.entries.fold(line, (String text, MapEntry<String, String> slot) {
          if (!text.contains(slot.key)) return text;
          return text.replaceAll(slot.key, slot.value);
        }),
    ];

    return LyricSong(
      title: _titleFor(trip: trip, places: places),
      sections: [
        for (final LyricSection section in sections)
          LyricSection(
            id: section.id,
            label: section.label,
            variants: [
              for (final List<String> variant in section.variants)
                fill(variant),
            ],
          ),
      ],
    );
  }

  @override
  Future<LyricSection> rewriteSection(LyricSection section) async {
    final int next = (section.variantIndex + 1) % section.variants.length;
    return section.copyWith(variantIndex: next);
  }

  @override
  Future<LyricistReply> respondToFeedback({
    required String feedback,
    required LyricSong song,
  }) async {
    final String targetId = _targetSectionFor(feedback);
    final List<LyricSection> sections = [
      for (final LyricSection s in song.sections)
        if (s.id == targetId) await rewriteSection(s) else s,
    ];
    return LyricistReply(
      reply: _replyFor(targetId),
      song: song.copyWith(sections: sections),
    );
  }

  /// Maps free-form feedback to the section it asks about; the chorus is the
  /// default target when nothing specific is named.
  String _targetSectionFor(String feedback) {
    final String f = feedback.toLowerCase();
    if (f.contains('chorus') || f.contains('hook')) return 'ch';
    if (f.contains('intro') || f.contains('opening')) return 'intro';
    if (f.contains('verse 2') || f.contains('second verse')) return 'v2';
    if (f.contains('verse 1') ||
        f.contains('first verse') ||
        f.contains('verse')) {
      return 'v1';
    }
    if (f.contains('bridge')) return 'br';
    if (f.contains('outro') || f.contains('ending')) return 'out';
    return 'ch';
  }

  String _replyFor(String sectionId) {
    switch (sectionId) {
      case 'ch':
        return 'Done — I punched up the chorus and let the wrong turns do the talking.';
      case 'v1':
        return "Rewrote verse 1. Kept the best incident — it's the good part.";
      case 'v2':
        return 'Verse 2 reworked — the second-day chaos lands harder now.';
      case 'br':
        return 'Reworked the bridge so the quiet moment lands a little softer.';
      case 'intro':
        return 'New intro. Sets the scene without spoiling the wrong turns.';
      case 'out':
        return 'New outro — sends everyone home smiling.';
    }
    return 'Done — give that section another look.';
  }

  String _titleFor({required String trip, required List<String> places}) {
    if (places.length >= 2) return 'Every Wrong Turn';
    if (trip.isNotEmpty && trip != 'the trip') return 'The $trip Tapes';
    return 'Every Wrong Turn';
  }

  /// Participant first names, deduplicated, with a fallback for empty crews.
  List<String> _cleanNames(List<String> participants) {
    final List<String> names = [];
    for (final String raw in participants) {
      final String name = raw.trim().split(' ').first;
      if (name.isEmpty || names.contains(name)) continue;
      names.add(name);
    }
    return names.isEmpty ? const ['the crew'] : names;
  }

  String _joinNames(List<String> names) {
    if (names.length <= 1) return names.join();
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  /// Pinned place names in trip order, deduplicated and trimmed.
  List<String> _placesOf(List<TimelineMemory> memories) {
    final List<String> places = [];
    for (final TimelineMemory m in memories) {
      if (!m.isPinned) continue;
      final String place = m.locationName!.trim();
      if (!places.contains(place)) places.add(place);
    }
    return places;
  }

  /// First sentence of a memory, capped to [_maxSnippetLength] on a word
  /// boundary, so user text lands inside a lyric line readably.
  String _snippet(String text) {
    final String trimmed = text.trim();
    final RegExpMatch? sentenceEnd = RegExp(r'[.!?]').firstMatch(trimmed);
    String snippet = sentenceEnd != null && sentenceEnd.start > 0
        ? trimmed.substring(0, sentenceEnd.start)
        : trimmed;
    if (snippet.length > _maxSnippetLength) {
      snippet = snippet.substring(0, _maxSnippetLength);
      final int lastSpace = snippet.lastIndexOf(' ');
      if (lastSpace > 0) snippet = snippet.substring(0, lastSpace);
      snippet = '$snippet…';
    }
    return snippet;
  }
}
