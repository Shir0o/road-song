import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_models.dart';

/// A guest upload that has not reached the backend yet: the full payload
/// (media bytes included) plus the trip it belongs to. Persisted so a
/// dropped connection never loses the guest's input (issue #31, user story
/// 53: graceful degradation — uploads queued with a visible status).
class PendingUpload {
  final String tripCode;
  final String contributor;
  final String author;
  final MemoryType type;
  final Uint8List bytes;
  final String contentType;
  final String caption;
  final String text;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const PendingUpload({
    required this.tripCode,
    required this.contributor,
    required this.author,
    required this.type,
    required this.bytes,
    required this.contentType,
    this.caption = '',
    this.text = '',
    this.locationName,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tripCode': tripCode,
      'contributor': contributor,
      'author': author,
      'type': type.name,
      'bytes': base64Encode(bytes),
      'contentType': contentType,
      'caption': caption,
      'text': text,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PendingUpload.fromJson(Map<String, dynamic> json) {
    return PendingUpload(
      tripCode: json['tripCode'] as String,
      contributor: json['contributor'] as String? ?? '',
      author: json['author'] as String? ?? '@guest',
      type:
          MemoryType.values.asNameMap()[json['type'] as String?] ??
          MemoryType.text,
      bytes: base64Decode(json['bytes'] as String? ?? ''),
      contentType: json['contentType'] as String? ?? 'text/plain',
      caption: json['caption'] as String? ?? '',
      text: json['text'] as String? ?? '',
      locationName: json['locationName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// SharedPreferences-backed queue of pending guest uploads (issue #31). The
/// queue survives app restarts, so a dropped connection never silently loses
/// input: the guest portal re-shows the queued upload with a retry after a
/// restart.
class PendingUploadStore {
  static const String _key = 'road_song_pending_uploads_v1';

  /// All queued uploads, newest first.
  Future<List<PendingUpload>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_key) ?? const [];
    final List<PendingUpload> uploads = <PendingUpload>[];
    for (final String entry in raw) {
      try {
        uploads.add(
          PendingUpload.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (_) {
        // A corrupt entry is dropped rather than blocking the queue.
      }
    }
    return uploads;
  }

  /// Queued uploads for [tripCode], newest first.
  Future<List<PendingUpload>> loadFor(String tripCode) async {
    final List<PendingUpload> all = await load();
    return <PendingUpload>[
      for (final PendingUpload upload in all)
        if (upload.tripCode == tripCode) upload,
    ];
  }

  /// Queues [upload], replacing any previous entry for the same trip code
  /// (one pending upload per trip keeps the retry affordance unambiguous).
  Future<void> save(PendingUpload upload) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_key) ?? const [];
    final List<String> kept = <String>[
      for (final String entry in raw)
        if (!_isFor(entry, upload.tripCode)) entry,
    ];
    kept.add(jsonEncode(upload.toJson()));
    await prefs.setStringList(_key, kept);
  }

  /// Removes the queued upload for [tripCode] (delivered or discarded).
  Future<void> remove(String tripCode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_key) ?? const [];
    final List<String> kept = <String>[
      for (final String entry in raw)
        if (!_isFor(entry, tripCode)) entry,
    ];
    await prefs.setStringList(_key, kept);
  }

  bool _isFor(String entry, String tripCode) {
    try {
      final Map<String, dynamic> json =
          jsonDecode(entry) as Map<String, dynamic>;
      return json['tripCode'] == tripCode;
    } catch (_) {
      return false;
    }
  }
}
