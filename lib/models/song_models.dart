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
}

/// A generated lyric draft: title plus the ordered modular sections.
class LyricSong {
  final String title;
  final int draftNumber;
  final List<LyricSection> sections;

  const LyricSong({
    required this.title,
    this.draftNumber = 1,
    required this.sections,
  });

  LyricSection? section(String id) {
    for (final LyricSection s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  LyricSong copyWith({
    String? title,
    int? draftNumber,
    List<LyricSection>? sections,
  }) {
    return LyricSong(
      title: title ?? this.title,
      draftNumber: draftNumber ?? this.draftNumber,
      sections: sections ?? this.sections,
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
