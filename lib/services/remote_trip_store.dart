import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/song_models.dart';
import '../models/trip_models.dart';
import 'trip_store.dart';

/// Base URL for the hosted trip store. Overridable at build time:
///
///   flutter build web --dart-define=ROAD_SONG_API_BASE=https://…
///
/// Defaults to the local fake backend used by tests (see
/// `test/fake_backend.dart`); the app never talks to a real network in CI.
const String kDefaultApiBase = String.fromEnvironment(
  'ROAD_SONG_API_BASE',
  defaultValue: 'http://localhost:8787/api',
);

/// The trip link shape guests open: `roadsong.app/t/<tripCode>`.
const String kTripLinkHost = 'roadsong.app';

/// Parses a trip link (or bare code) into the trip code, or null.
///
/// Accepts `roadsong.app/t/<code>`, `https://roadsong.app/t/<code>`, and a
/// bare `<code>` (used by the guest route when the app boots from a link).
String? tripCodeFromLink(String link) {
  final String trimmed = link.trim();
  if (trimmed.isEmpty) return null;
  final RegExpMatch? match = RegExp(
    r'^(?:https?://)?(?:roadsong\.app/)?/?t/([A-Za-z0-9-]+)$',
  ).firstMatch(trimmed);
  if (match != null) return match.group(1);
  // A bare code (no slashes) is also accepted.
  if (RegExp(r'^[A-Za-z0-9-]+$').hasMatch(trimmed)) return trimmed;
  return null;
}

/// Builds the shareable trip link for a trip code.
String buildTripLink(String tripCode) => '$kTripLinkHost/t/$tripCode';

/// Thrown when the backend rejects a request (non-2xx).
class TripStoreHttpException implements Exception {
  final int statusCode;
  final String message;

  const TripStoreHttpException(this.statusCode, this.message);

  @override
  String toString() => 'TripStoreHttpException($statusCode): $message';
}

/// Result of a media upload attempt: the memory was created on the backend
/// (with a media URL) or the attempt failed and can be retried.
class TripUploadResult {
  final bool success;
  final String? error;

  const TripUploadResult.success() : success = true, error = null;
  const TripUploadResult.failure(this.error) : success = false;

  bool get isSuccess => success;
}

/// The HTTP contract the hosted trip store speaks. [RemoteTripStore] and the
/// fake backend in tests both implement this; the contract suite drives the
/// client against the fake with no real network.
abstract class TripStoreClient {
  /// Creates a trip on the backend and returns it (with its generated code).
  Future<Trip> createTrip(TripDraft draft);

  /// Fetches a trip (and its memories) by trip code.
  Future<Trip> fetchTrip(String tripCode);

  /// Mints a short-lived presigned PUT URL for a photo/video upload.
  Future<({String uploadUrl, String mediaKey})> requestUploadUrl({
    required String tripCode,
    required String type,
    required String contentType,
    required int contentLength,
  });

  /// PUTs media bytes to the upload URL, reporting progress. The fake backend
  /// simulates a dropped connection here for the retry tests.
  Future<void> putMedia(
    String uploadUrl,
    Uint8List bytes,
    String contentType, {
    void Function(double progress)? onProgress,
  });

  /// Creates a memory on the backend. For photo/video memories, [mediaKey]
  /// must be the key returned by [requestUploadUrl] after the bytes were PUT.
  Future<TimelineMemory> createMemory(
    String tripCode,
    TimelineMemory memory, {
    String? mediaKey,
  });

  /// Deletes a memory (and its media) from the backend.
  Future<void> deleteMemory(String tripCode, String memoryId);
}

/// [TripStoreClient] over plain HTTP (the `http` package). The base URL is
/// injectable; production uses [kDefaultApiBase].
class HttpTripStoreClient implements TripStoreClient {
  final String baseUrl;
  final http.Client _client;

  HttpTripStoreClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? kDefaultApiBase,
      _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const TripStoreHttpException(500, 'Malformed response');
    }
    return decoded;
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'Request failed (${response.statusCode})';
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        message = decoded['error'] as String;
      }
    } catch (_) {}
    throw TripStoreHttpException(response.statusCode, message);
  }

  @override
  Future<Trip> createTrip(TripDraft draft) async {
    final http.Response response = await _client.post(
      _uri('/trips'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'name': draft.name,
        'firstDay': draft.firstDay,
        'lastDay': draft.lastDay,
        'coverIndex': draft.coverIndex,
      }),
    );
    _ensureOk(response);
    return Trip.fromJson(_decode(response));
  }

  @override
  Future<Trip> fetchTrip(String tripCode) async {
    final http.Response response = await _client.get(_uri('/trip/$tripCode'));
    _ensureOk(response);
    return Trip.fromJson(_decode(response));
  }

  @override
  Future<({String uploadUrl, String mediaKey})> requestUploadUrl({
    required String tripCode,
    required String type,
    required String contentType,
    required int contentLength,
  }) async {
    final http.Response response = await _client.post(
      _uri('/trip/$tripCode/upload-url'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'type': type,
        'contentType': contentType,
        'contentLength': contentLength,
      }),
    );
    _ensureOk(response);
    final Map<String, dynamic> body = _decode(response);
    return (
      uploadUrl: body['uploadUrl'] as String,
      mediaKey: body['mediaKey'] as String,
    );
  }

  @override
  Future<void> putMedia(
    String uploadUrl,
    Uint8List bytes,
    String contentType, {
    void Function(double progress)? onProgress,
  }) async {
    // Report progress in coarse steps so the UI updates without hammering
    // the frame; the fake backend in tests can simulate a drop mid-upload.
    const int steps = 8;
    for (int i = 1; i <= steps; i++) {
      onProgress?.call(i / steps);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final http.Response response = await _client.put(
      Uri.parse(uploadUrl),
      headers: {'content-type': contentType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TripStoreHttpException(
        response.statusCode,
        'Upload failed (${response.statusCode}) — try again.',
      );
    }
  }

  @override
  Future<TimelineMemory> createMemory(
    String tripCode,
    TimelineMemory memory, {
    String? mediaKey,
  }) async {
    final http.Response response = await _client.post(
      _uri('/trip/$tripCode/memories'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'type': memory.type.name,
        'contributor': memory.contributor,
        'author': memory.author,
        'caption': memory.caption,
        'text': memory.text,
        'day': memory.day,
        'dayDate': memory.dayDate,
        'locationName': memory.locationName,
        'latitude': memory.latitude,
        'longitude': memory.longitude,
        'mediaKey': mediaKey,
      }),
    );
    _ensureOk(response);
    return TimelineMemory.fromJson(_decode(response));
  }

  @override
  Future<void> deleteMemory(String tripCode, String memoryId) async {
    final http.Response response = await _client.delete(
      _uri('/trip/$tripCode/memories/$memoryId'),
    );
    _ensureOk(response);
  }
}

/// Uploads a guest memory to the backend: mints a presigned PUT URL, PUTs
/// the bytes (reporting progress), then creates the memory row. Returns a
/// [TripUploadResult] so the guest UI can show progress and a retry.
Future<TripUploadResult> uploadGuestMemoryTo(
  TripStoreClient client, {
  required String tripCode,
  required String contributor,
  required String author,
  required MemoryType type,
  required Uint8List bytes,
  required String contentType,
  String caption = '',
  String text = '',
  String? locationName,
  double? latitude,
  double? longitude,
  DateTime Function()? now,
  void Function(double progress)? onProgress,
}) async {
  try {
    final ({String uploadUrl, String mediaKey}) urls = await client
        .requestUploadUrl(
          tripCode: tripCode,
          type: type.name,
          contentType: contentType,
          contentLength: bytes.length,
        );
    await client.putMedia(
      urls.uploadUrl,
      bytes,
      contentType,
      onProgress: onProgress,
    );
    await client.createMemory(
      tripCode,
      TimelineMemory(
        id: 'remote-${DateTime.now().microsecondsSinceEpoch}',
        author: author,
        contributor: contributor,
        time: _clockTime(now?.call() ?? DateTime.now()),
        text: text,
        caption: caption,
        type: type,
        createdAt: now?.call() ?? DateTime.now(),
        day: 1,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
      ),
      mediaKey: urls.mediaKey,
    );
    return TripUploadResult.success();
  } on TripStoreHttpException catch (e) {
    return TripUploadResult.failure(e.message);
  } catch (_) {
    return TripUploadResult.failure(
      'Connection dropped — your upload is safe to retry.',
    );
  }
}

String _clockTime(DateTime t) {
  final int hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final String minutes = t.minute.toString().padLeft(2, '0');
  return '$hour12:$minutes ${t.hour >= 12 ? 'PM' : 'AM'}';
}

/// A [TripStore] backed by the hosted trip store. It mirrors the active trip
/// locally (so the diary renders instantly and offline edits keep working)
/// and polls the backend on a bounded interval, merging new guest memories
/// into the trip — the diary (ChangeNotifier-driven) updates live without an
/// app restart.
///
/// The clock and poll interval are injectable for tests; the client is
/// injectable so the contract suite can drive it against the fake backend.
class RemoteTripStore extends ChangeNotifier implements TripStore {
  final TripStoreClient client;
  final Duration pollInterval;
  final DateTime Function() now;

  final List<Trip> _trips = [];
  String? _activeTripId;
  Timer? _pollTimer;
  bool _disposed = false;

  /// When set, the next poll fails once (simulated drop) — tests use this to
  /// exercise the retry affordance.
  bool simulateNextPollFailure = false;

  RemoteTripStore({
    required this.client,
    this.pollInterval = const Duration(seconds: 10),
    this.now = DateTime.now,
  });

  @override
  List<Trip> get trips => List.unmodifiable(_trips);

  @override
  Trip? get activeTrip {
    if (_trips.isEmpty) return null;
    if (_activeTripId == null) return _trips.last;
    try {
      return _trips.firstWhere((t) => t.id == _activeTripId);
    } catch (_) {
      return _trips.last;
    }
  }

  @override
  Future<void> init() async {
    _startPolling();
  }

  /// Starts (or restarts) the bounded polling loop. Polls stop while a poll
  /// is in flight and never overlap.
  void _startPolling() {
    _pollTimer?.cancel();
    if (_disposed) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_disposed) return;
    final Trip? trip = activeTrip;
    if (trip == null) return;
    if (simulateNextPollFailure) {
      simulateNextPollFailure = false;
      return;
    }
    try {
      final Trip remote = await client.fetchTrip(trip.code);
      if (_disposed) return;
      _mergeRemote(remote);
    } catch (_) {
      // A failed poll is silent: the next tick retries. Local edits are never
      // lost because the local mirror is the source of truth for the UI.
    }
  }

  /// Merges the remote trip into the local mirror: new memories are appended
  /// (in contribution order), existing ones are updated in place, and
  /// deletions are honored. Local-only memories (created offline) survive.
  void _mergeRemote(Trip remote) {
    final int index = _trips.indexWhere((t) => t.id == remote.id);
    if (index == -1) return;
    final Trip local = _trips[index];
    final Map<String, TimelineMemory> byId = {
      for (final TimelineMemory m in local.memories) m.id: m,
    };
    final List<TimelineMemory> merged = [];
    for (final TimelineMemory remoteMemory in remote.memories) {
      final TimelineMemory? localMemory = byId.remove(remoteMemory.id);
      merged.add(localMemory ?? remoteMemory);
    }
    // Local-only memories (not yet on the backend) keep their place at the
    // end, in contribution order.
    merged.addAll(byId.values);
    // The lyric draft and song artifact are local mirror artifacts (the
    // backend has no lyrics/audio endpoints in v1); keep them across polls.
    _trips[index] = remote.copyWith(
      memories: merged,
      song: local.song,
      songArtifact: local.songArtifact,
    );
    notifyListeners();
  }

  @override
  Future<void> addTrip(Trip trip) async {
    _trips.removeWhere((t) => t.id == trip.id);
    _trips.add(trip);
    _activeTripId = trip.id;
    notifyListeners();
  }

  @override
  Future<void> setActiveTrip(String tripId) async {
    if (_trips.any((t) => t.id == tripId)) {
      _activeTripId = tripId;
      notifyListeners();
    }
  }

  @override
  Future<void> addCrewMember(String tripId, CrewMember member) async {
    final int index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;
    final Trip trip = _trips[index];
    final List<CrewMember> updatedCrew = List<CrewMember>.from(trip.crew);
    final int existingIndex = updatedCrew.indexWhere((c) => c.id == member.id);
    if (existingIndex != -1) {
      updatedCrew[existingIndex] = member;
    } else {
      updatedCrew.add(member);
    }
    _trips[index] = trip.copyWith(crew: updatedCrew);
    notifyListeners();
  }

  @override
  List<TimelineMemory> memoriesFor(String tripId) {
    final int index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return const [];
    return List.unmodifiable(_trips[index].memories);
  }

  @override
  Future<void> addMemory(String tripId, TimelineMemory memory) async {
    _mutateMemories(tripId, (current) {
      current.removeWhere((m) => m.id == memory.id);
      current.add(memory);
      return current;
    });
  }

  @override
  Future<void> updateMemory(String tripId, TimelineMemory memory) async {
    _mutateMemories(tripId, (current) {
      final int index = current.indexWhere((m) => m.id == memory.id);
      if (index == -1) {
        current.add(memory);
      } else {
        current[index] = memory;
      }
      return current;
    });
  }

  @override
  Future<void> deleteMemory(String tripId, String memoryId) async {
    _mutateMemories(
      tripId,
      (current) => current..removeWhere((m) => m.id == memoryId),
    );
  }

  void _mutateMemories(
    String tripId,
    List<TimelineMemory> Function(List<TimelineMemory> current) mutate,
  ) {
    final int index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;
    final List<TimelineMemory> updated = mutate(
      List<TimelineMemory>.from(_trips[index].memories),
    );
    _trips[index] = _trips[index].copyWith(memories: updated);
    notifyListeners();
  }

  @override
  LyricSong? songFor(String tripId) {
    final int index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return null;
    return _trips[index].song;
  }

  @override
  Future<void> saveSong(String tripId, LyricSong song) async {
    final int index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;
    _trips[index] = _trips[index].copyWith(song: song);
    notifyListeners();
  }

  @override
  SongArtifact? songArtifactFor(String tripId) {
    final int index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return null;
    return _trips[index].songArtifact;
  }

  @override
  Future<void> saveSongArtifact(String tripId, SongArtifact artifact) async {
    final int index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;
    _trips[index] = _trips[index].copyWith(songArtifact: artifact);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
