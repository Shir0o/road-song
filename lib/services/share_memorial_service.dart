import '../models/song_models.dart';
import '../models/trip_models.dart';

/// Metadata for OpenGraph / Twitter web preview cards.
class WebCardMetadata {
  final String title;
  final String description;
  final String imageUrl;
  final String shareUrl;
  final String siteName;
  final String audioDurationFormatted;
  final String vibeLabel;
  final List<String> participantNames;

  const WebCardMetadata({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.shareUrl,
    this.siteName = 'Road Song',
    required this.audioDurationFormatted,
    required this.vibeLabel,
    required this.participantNames,
  });

  /// Generates the HTML meta tags block for web sharing.
  String toHtmlMetaTags() {
    return '''
<meta property="og:type" content="music.song" />
<meta property="og:title" content="$title — Road Song Memorial" />
<meta property="og:description" content="$description" />
<meta property="og:image" content="$imageUrl" />
<meta property="og:url" content="$shareUrl" />
<meta property="og:site_name" content="$siteName" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="$title" />
<meta name="twitter:description" content="$description" />
<meta name="twitter:image" content="$imageUrl" />
''';
  }
}

/// Service generating tokenized memorial links and web preview card metadata.
class ShareMemorialService {
  const ShareMemorialService();

  /// Converts a string into a clean URL-safe slug.
  String slugify(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'memorial' : cleaned;
  }

  /// Builds a tokenized memorial deep link for a trip and song.
  String buildShareLink({
    required String tripName,
    required String songTitle,
  }) {
    final String tripSlug = slugify(tripName);
    final String songSlug = slugify(songTitle);
    return 'https://roadsong.app/m/$tripSlug-$songSlug';
  }

  /// Generates OpenGraph / Twitter Card preview metadata.
  WebCardMetadata generatePreviewMetadata({
    required String tripName,
    required SongTimeline timeline,
    required List<TimelineMemory> memories,
    required List<CrewMember> crew,
  }) {
    final String shareUrl = buildShareLink(
      tripName: tripName,
      songTitle: timeline.title,
    );

    // Pick top image from memories or fallback
    String coverImage = 'https://roadsong.app/assets/memorial_cover.jpg';
    for (final memory in memories) {
      if (memory.imageUrl != null && memory.imageUrl!.isNotEmpty) {
        coverImage = memory.imageUrl!;
        break;
      }
    }

    final List<String> participants = crew.isNotEmpty
        ? crew.map((c) => c.name).toList()
        : memories.map((m) => m.author.replaceFirst('@', '')).toSet().toList();

    final int seconds = timeline.durationMs ~/ 1000;
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    final String durationFormatted = '$min:${sec.toString().padLeft(2, '0')}';

    final String description =
        'Listen to "$tripName: ${timeline.title}" (${timeline.bpm} BPM ${timeline.styleId}) crafted from ${memories.length} real moments.';

    return WebCardMetadata(
      title: '${timeline.title} ($tripName)',
      description: description,
      imageUrl: coverImage,
      shareUrl: shareUrl,
      audioDurationFormatted: durationFormatted,
      vibeLabel: timeline.styleId.toUpperCase(),
      participantNames: participants,
    );
  }
}
