import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'song_models.dart';
export '../services/trip_store.dart';

/// A draft of a new trip being created during onboarding.
class TripDraft {
  final String name;
  final String firstDay;
  final String lastDay;
  final int coverIndex;

  const TripDraft({
    this.name = '',
    this.firstDay = '',
    this.lastDay = '',
    this.coverIndex = 0,
  });

  TripDraft copyWith({
    String? name,
    String? firstDay,
    String? lastDay,
    int? coverIndex,
  }) {
    return TripDraft(
      name: name ?? this.name,
      firstDay: firstDay ?? this.firstDay,
      lastDay: lastDay ?? this.lastDay,
      coverIndex: coverIndex ?? this.coverIndex,
    );
  }

  bool get isValid => name.trim().isNotEmpty;
}

/// A friend that can be invited to a session.
class CrewMember {
  final String id;
  final String name;
  final String handle;
  final String initial;
  final Color color;
  final bool invited;

  const CrewMember({
    required this.id,
    required this.name,
    required this.handle,
    required this.initial,
    required this.color,
    this.invited = false,
  });

  CrewMember copyWith({
    String? id,
    String? name,
    String? handle,
    String? initial,
    Color? color,
    bool? invited,
  }) {
    return CrewMember(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      initial: initial ?? this.initial,
      color: color ?? this.color,
      invited: invited ?? this.invited,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'handle': handle,
      'initial': initial,
      'color': color.value,
      'invited': invited,
    };
  }

  factory CrewMember.fromJson(Map<String, dynamic> json) {
    return CrewMember(
      id: json['id'] as String,
      name: json['name'] as String,
      handle: json['handle'] as String,
      initial: json['initial'] as String,
      color: Color(json['color'] as int),
      invited: json['invited'] as bool? ?? false,
    );
  }
}

/// The type of media a guest can drop into a shared trip pool.
enum GuestDropType { photo, video, text }

/// A parsed guest drop with preserved capture metadata.
class GuestDrop {
  final GuestDropType type;
  final String author;
  final String content;
  final DateTime? capturedAt;
  final String? location;

  const GuestDrop({
    required this.type,
    required this.author,
    required this.content,
    this.capturedAt,
    this.location,
  });

  bool get isText => type == GuestDropType.text;
  bool get isPhoto => type == GuestDropType.photo;
  bool get isVideo => type == GuestDropType.video;
}

/// A fully created trip with its crew, session link, and contributed memories.
class Trip {
  final String id;
  final String name;
  final String firstDay;
  final String lastDay;
  final int coverIndex;
  final List<CrewMember> crew;
  final String sessionLink;
  final DateTime createdAt;
  final List<TimelineMemory> memories;

  /// The latest lyric draft ("Write our song" output), persisted with the
  /// trip so hand edits and rewrites survive restarts. Null until the song
  /// has been written once.
  final LyricSong? song;

  /// The finished-memorial artifact (vibe, audio asset, Making Song stage
  /// state), persisted with the trip so the unlocked song survives restarts.
  /// Null until a sound has been chosen. Remaking replaces this and keeps
  /// [song].
  final SongArtifact? songArtifact;

  const Trip({
    required this.id,
    required this.name,
    required this.firstDay,
    required this.lastDay,
    required this.coverIndex,
    required this.crew,
    required this.sessionLink,
    required this.createdAt,
    this.memories = const [],
    this.song,
    this.songArtifact,
  });

  String get dateRange => '$firstDay – $lastDay';

  /// The trip code from the session link (`roadsong.app/t/<code>`), or the
  /// trip id when the link has no code shape. The backend scopes all access
  /// by this code.
  String get code {
    final RegExpMatch? match = RegExp(
      r'^(?:https?://)?(?:roadsong\.app/)?/?t/([A-Za-z0-9-]+)$',
    ).firstMatch(sessionLink);
    if (match != null) return match.group(1)!;
    return id;
  }

  Trip copyWith({
    String? id,
    String? name,
    String? firstDay,
    String? lastDay,
    int? coverIndex,
    List<CrewMember>? crew,
    String? sessionLink,
    DateTime? createdAt,
    List<TimelineMemory>? memories,
    LyricSong? song,
    SongArtifact? songArtifact,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      firstDay: firstDay ?? this.firstDay,
      lastDay: lastDay ?? this.lastDay,
      coverIndex: coverIndex ?? this.coverIndex,
      crew: crew ?? this.crew,
      sessionLink: sessionLink ?? this.sessionLink,
      createdAt: createdAt ?? this.createdAt,
      memories: memories ?? this.memories,
      song: song ?? this.song,
      songArtifact: songArtifact ?? this.songArtifact,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'firstDay': firstDay,
      'lastDay': lastDay,
      'coverIndex': coverIndex,
      'crew': crew.map((c) => c.toJson()).toList(),
      'sessionLink': sessionLink,
      'createdAt': createdAt.toIso8601String(),
      'memories': memories.map((m) => m.toJson()).toList(),
      'song': song?.toJson(),
      'songArtifact': songArtifact?.toJson(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      firstDay: json['firstDay'] as String? ?? '',
      lastDay: json['lastDay'] as String? ?? '',
      coverIndex: json['coverIndex'] as int? ?? 0,
      crew:
          (json['crew'] as List<dynamic>?)
              ?.map((item) => CrewMember.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      sessionLink: json['sessionLink'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      memories:
          (json['memories'] as List<dynamic>?)
              ?.map(
                (item) => TimelineMemory.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      song: json['song'] == null
          ? null
          : LyricSong.fromJson(json['song'] as Map<String, dynamic>),
      songArtifact: json['songArtifact'] == null
          ? null
          : SongArtifact.fromJson(json['songArtifact'] as Map<String, dynamic>),
    );
  }
}

/// The kind of media a memory carries. Photos cover both gallery and camera
/// captures; [text] is lore with no media attachment.
enum MemoryType { photo, video, text }

/// The trip's local anonymous creator identity — v1 has no accounts, so the
/// person holding the device is the contributor for anything added in-app.
const String kCreatorHandle = '@you';
const String kCreatorName = 'You';

/// A single memory in a trip diary: media or lore, optionally pinned to a
/// place. Pinned memories (with [locationName]) become stops on the trip
/// route; nullable [latitude]/[longitude] are stored from day one so a real
/// map can be dropped in later without a data migration.
class TimelineMemory {
  final String id;

  /// Display handle of the contributor (e.g. `@you`, `@maya`).
  final String author;

  /// Display name signed on the memory (e.g. `You`, `Maya`). Falls back to
  /// [author] for fixtures that only carry a handle.
  final String contributor;
  final String time;
  final String text;

  /// 1-based day of the trip this memory belongs to (feed grouping).
  final int day;

  /// Optional date label shown in the day header (e.g. 'JUN 12').
  final String? dayDate;

  /// When the memory was actually created. Null on canned fixtures that only
  /// carry the display [time].
  final DateTime? createdAt;

  /// Place name of the pinned location milestone, if the memory was pinned.
  final String? locationName;
  final double? latitude;
  final double? longitude;

  final int likes;
  final bool likedByMe;

  /// Polaroid photo: either a remote [imageUrl], raw [photoBytes] (captured
  /// in-app), or a stylized photo wash when only [photoCaption] is set.
  final String? imageUrl;
  final String? photoCaption;
  final Uint8List? photoBytes;

  /// Short video clip reference: a remote [videoUrl] or raw [videoBytes] for
  /// in-app clips. The bytes are never decoded by the UI or by tests.
  final String? videoUrl;
  final Uint8List? videoBytes;

  /// Contributor-editable caption shown on the memory card.
  final String caption;

  final MemoryType? _mediaType;

  /// The memory's media kind. Explicit when set by the composer; otherwise
  /// derived from the attached media so legacy fixtures stay meaningful.
  MemoryType get type {
    if (_mediaType != null) return _mediaType;
    if (hasVideo) return MemoryType.video;
    if (hasPhoto) return MemoryType.photo;
    return MemoryType.text;
  }

  // Legacy timeline node styling (Evidence screen + canned fixtures). It is
  // not persisted: only [rotationDegrees] and [authorColor] round-trip.
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String? category;
  final Color? authorColor;

  final double rotationDegrees;

  const TimelineMemory({
    required this.id,
    required this.author,
    required this.time,
    required this.text,
    this.contributor = '',
    this.day = 1,
    this.dayDate,
    this.createdAt,
    this.locationName,
    this.latitude,
    this.longitude,
    this.likes = 0,
    this.likedByMe = false,
    this.imageUrl,
    this.photoCaption,
    this.photoBytes,
    this.videoUrl,
    this.videoBytes,
    this.caption = '',
    MemoryType? type,
    this.icon = Icons.notes,
    this.iconBg = const Color(0xFFF1E7D1),
    this.iconColor = Colors.black,
    this.category,
    this.authorColor,
    this.rotationDegrees = 0.0,
  }) : _mediaType = type;

  bool get hasPhoto => imageUrl != null || photoBytes != null;

  bool get hasVideo => videoUrl != null || videoBytes != null;

  /// Caption a card should show, falling back to the legacy polaroid label.
  String get displayCaption =>
      caption.isNotEmpty ? caption : (photoCaption ?? '');

  /// Contributor name a card should show, falling back to the handle.
  String get displayContributor =>
      contributor.isNotEmpty ? contributor : author;

  /// Whether this memory is a pin-able route stop.
  bool get isPinned => locationName != null && locationName!.trim().isNotEmpty;

  TimelineMemory copyWith({
    String? id,
    String? author,
    String? contributor,
    String? time,
    String? text,
    int? day,
    String? dayDate,
    DateTime? createdAt,
    String? locationName,
    double? latitude,
    double? longitude,
    int? likes,
    bool? likedByMe,
    String? imageUrl,
    String? photoCaption,
    Uint8List? photoBytes,
    String? videoUrl,
    Uint8List? videoBytes,
    String? caption,
    MemoryType? type,
    IconData? icon,
    Color? iconBg,
    Color? iconColor,
    String? category,
    Color? authorColor,
    double? rotationDegrees,
  }) {
    return TimelineMemory(
      id: id ?? this.id,
      author: author ?? this.author,
      contributor: contributor ?? this.contributor,
      time: time ?? this.time,
      text: text ?? this.text,
      day: day ?? this.day,
      dayDate: dayDate ?? this.dayDate,
      createdAt: createdAt ?? this.createdAt,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      likes: likes ?? this.likes,
      likedByMe: likedByMe ?? this.likedByMe,
      imageUrl: imageUrl ?? this.imageUrl,
      photoCaption: photoCaption ?? this.photoCaption,
      photoBytes: photoBytes ?? this.photoBytes,
      videoUrl: videoUrl ?? this.videoUrl,
      videoBytes: videoBytes ?? this.videoBytes,
      caption: caption ?? this.caption,
      type: type ?? _mediaType,
      icon: icon ?? this.icon,
      iconBg: iconBg ?? this.iconBg,
      iconColor: iconColor ?? this.iconColor,
      category: category ?? this.category,
      authorColor: authorColor ?? this.authorColor,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }

  /// JSON round-trip used by [PreferencesTripStore]; photo and video bytes are
  /// base64-encoded so SharedPreferences can carry them.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'contributor': contributor,
      'time': time,
      'text': text,
      'day': day,
      'dayDate': dayDate,
      'createdAt': createdAt?.toIso8601String(),
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'likes': likes,
      'likedByMe': likedByMe,
      'imageUrl': imageUrl,
      'photoCaption': photoCaption,
      'photoBytes': photoBytes == null ? null : base64Encode(photoBytes!),
      'videoUrl': videoUrl,
      'videoBytes': videoBytes == null ? null : base64Encode(videoBytes!),
      'caption': caption,
      'type': type.name,
      'authorColor': authorColor?.toARGB32(),
      'rotationDegrees': rotationDegrees,
    };
  }

  factory TimelineMemory.fromJson(Map<String, dynamic> json) {
    final String? rawPhoto = json['photoBytes'] as String?;
    final String? rawVideo = json['videoBytes'] as String?;
    return TimelineMemory(
      id: json['id'] as String,
      author: json['author'] as String? ?? kCreatorHandle,
      contributor: json['contributor'] as String? ?? '',
      time: json['time'] as String? ?? '',
      text: json['text'] as String? ?? '',
      day: json['day'] as int? ?? 1,
      dayDate: json['dayDate'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      locationName: json['locationName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      likes: json['likes'] as int? ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      photoCaption: json['photoCaption'] as String?,
      photoBytes: rawPhoto == null ? null : base64Decode(rawPhoto),
      videoUrl: json['videoUrl'] as String?,
      videoBytes: rawVideo == null ? null : base64Decode(rawVideo),
      caption: json['caption'] as String? ?? '',
      type: MemoryType.values.asNameMap()[json['type'] as String?],
      authorColor: json['authorColor'] == null
          ? null
          : Color(json['authorColor'] as int),
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// A positioned label pin for the legacy Evidence map overlay.
class MapPin {
  final String memoryId;
  final String label;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;

  const MapPin({
    required this.memoryId,
    required this.label,
    this.left,
    this.top,
    this.right,
    this.bottom,
  });
}
