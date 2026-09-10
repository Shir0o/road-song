import 'dart:typed_data';

import 'package:road_song/models/trip_models.dart';
import 'package:road_song/services/remote_trip_store.dart';

/// In-memory fake backend implementing the same [TripStoreClient] contract as
/// the hosted Worker. The store-client contract suite drives the client
/// against this fake; the whole-app guest flow injects it at the app seam.
/// No real network in CI.
///
/// The fake enforces the same rules as the Worker:
/// - trip-code scope: memories are only reachable under their own trip's code;
/// - upload guardrails: 12 MB photos / 64 MB videos are rejected with 413;
/// - media keys must belong to the trip and the object must exist.
///
/// It can also simulate a dropped upload ([simulateNextUploadDrop]) so the
/// guest retry affordance is exercised deterministically.
class FakeBackend implements TripStoreClient {
  final List<Trip> trips = [];
  final Map<String, List<TimelineMemory>> _memories = {};

  /// Media keys that "exist" in the fake R2 (uploaded via PUT).
  final Set<String> mediaKeys = {};

  /// When true, the next upload PUT fails once (simulated drop).
  bool simulateNextUploadDrop = false;

  /// When true, the next [fetchTrip] throws once (simulated poll drop).
  bool simulateNextFetchFailure = false;

  /// When set, [requestUploadUrl] rejects with this status (guardrail tests).
  int? rejectUploadUrlWithStatus;

  /// When set, [createMemory] rejects with this status (scope tests).
  int? rejectCreateMemoryWithStatus;

  /// When set, [deleteMemory] rejects with this status (scope tests).
  int? rejectDeleteMemoryWithStatus;

  /// The trip code the fake considers "foreign" for cross-trip scope tests.
  String? foreignTripCode;

  /// The memory id the fake considers "foreign" for cross-trip scope tests.
  String? foreignMemoryId;

  List<TimelineMemory> memoriesFor(String tripCode) =>
      List.unmodifiable(_memories[tripCode] ?? const []);

  @override
  Future<Trip> createTrip(TripDraft draft) async {
    final String code = '${_slug(draft.name)}-${trips.length + 1}';
    final Trip trip = Trip(
      id: 'trip-${trips.length + 1}',
      name: draft.name,
      firstDay: draft.firstDay,
      lastDay: draft.lastDay,
      coverIndex: draft.coverIndex,
      crew: const [],
      sessionLink: buildTripLink(code),
      createdAt: DateTime.now(),
    );
    trips.add(trip);
    _memories[trip.code] = [];
    return trip;
  }

  String _slug(String name) {
    final String cleaned = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'trip' : cleaned;
  }

  @override
  Future<Trip> fetchTrip(String tripCode) async {
    if (simulateNextFetchFailure) {
      simulateNextFetchFailure = false;
      throw const TripStoreHttpException(503, 'Simulated poll drop');
    }
    Trip? trip;
    for (final Trip t in trips) {
      if (t.code == tripCode) {
        trip = t;
        break;
      }
    }
    if (trip == null) {
      throw const TripStoreHttpException(404, 'Trip not found');
    }
    return trip.copyWith(memories: memoriesFor(tripCode));
  }

  @override
  Future<({String uploadUrl, String mediaKey})> requestUploadUrl({
    required String tripCode,
    required String type,
    required String contentType,
    required int contentLength,
  }) async {
    if (rejectUploadUrlWithStatus != null) {
      final int status = rejectUploadUrlWithStatus!;
      rejectUploadUrlWithStatus = null;
      throw TripStoreHttpException(status, 'Rejected by fake backend');
    }
    Trip? trip;
    for (final Trip t in trips) {
      if (t.code == tripCode) {
        trip = t;
        break;
      }
    }
    if (trip == null) {
      throw const TripStoreHttpException(404, 'Trip not found');
    }
    final int limit = type == 'photo' ? 12 * 1024 * 1024 : 64 * 1024 * 1024;
    if (contentLength > limit) {
      throw TripStoreHttpException(
        413,
        type == 'photo'
            ? 'That file is too big — keep photos under 12.0 MB.'
            : 'That file is too big — keep clips under 64.0 MB.',
      );
    }
    final String extension = contentType.split('/').last.split(';').first;
    final String mediaKey =
        'trips/${trip.id}/fake-${mediaKeys.length + 1}.$extension';
    return (
      uploadUrl: 'https://fake-backend.test/put/$mediaKey',
      mediaKey: mediaKey,
    );
  }

  /// The fake's "PUT to R2": records the key as existing. Simulates a drop
  /// when [simulateNextUploadDrop] is set.
  @override
  Future<void> putMedia(
    String uploadUrl,
    Uint8List bytes,
    String contentType, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    // A real async gap so the in-flight progress state is observable in
    // widget tests (and a dropped connection can interrupt mid-upload).
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (simulateNextUploadDrop) {
      simulateNextUploadDrop = false;
      throw const TripStoreHttpException(503, 'Simulated drop');
    }
    final String mediaKey = uploadUrl.split('/put/').last;
    mediaKeys.add(mediaKey);
    onProgress?.call(1.0);
  }

  @override
  Future<TimelineMemory> createMemory(
    String tripCode,
    TimelineMemory memory, {
    String? mediaKey,
  }) async {
    if (rejectCreateMemoryWithStatus != null) {
      final int status = rejectCreateMemoryWithStatus!;
      rejectCreateMemoryWithStatus = null;
      throw TripStoreHttpException(status, 'Rejected by fake backend');
    }
    Trip? trip;
    for (final Trip t in trips) {
      if (t.code == tripCode) {
        trip = t;
        break;
      }
    }
    if (trip == null) {
      throw const TripStoreHttpException(404, 'Trip not found');
    }
    if (memory.type != MemoryType.text) {
      if (mediaKey == null || !mediaKey.startsWith('trips/${trip.id}/')) {
        throw const TripStoreHttpException(
          400,
          'mediaKey must belong to this trip',
        );
      }
      if (!mediaKeys.contains(mediaKey)) {
        throw const TripStoreHttpException(
          400,
          'Media object not found — upload it first',
        );
      }
    }
    final TimelineMemory created = memory.copyWith(
      id: memory.id.isEmpty
          ? 'remote-${_memories[tripCode]!.length + 1}'
          : memory.id,
      imageUrl: memory.type == MemoryType.photo ? mediaKey : null,
      videoUrl: memory.type == MemoryType.video ? mediaKey : null,
    );
    _memories[tripCode]!.add(created);
    return created;
  }

  @override
  Future<void> deleteMemory(String tripCode, String memoryId) async {
    if (rejectDeleteMemoryWithStatus != null) {
      final int status = rejectDeleteMemoryWithStatus!;
      rejectDeleteMemoryWithStatus = null;
      throw TripStoreHttpException(status, 'Rejected by fake backend');
    }
    final List<TimelineMemory>? list = _memories[tripCode];
    if (list == null) {
      throw const TripStoreHttpException(404, 'Trip not found');
    }
    final int index = list.indexWhere((m) => m.id == memoryId);
    if (index == -1) {
      throw const TripStoreHttpException(404, 'Memory not found');
    }
    final TimelineMemory removed = list.removeAt(index);
    if (removed.imageUrl != null) mediaKeys.remove(removed.imageUrl);
    if (removed.videoUrl != null) mediaKeys.remove(removed.videoUrl);
  }
}
