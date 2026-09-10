import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_models.dart';
import '../models/trip_models.dart';

/// Abstract storage seam for trip creation, persistence, and retrieval.
///
/// Screens talk to this seam only — never to storage directly.
abstract class TripStore extends ChangeNotifier {
  factory TripStore() => InMemoryTripStore();
  factory TripStore.inMemory() => InMemoryTripStore();
  factory TripStore.persistent() => PreferencesTripStore();

  List<Trip> get trips;
  Trip? get activeTrip;

  Future<void> init();
  Future<void> addTrip(Trip trip);
  Future<void> setActiveTrip(String tripId);
  Future<void> addCrewMember(String tripId, CrewMember member);

  /// Memories contributed to [tripId], in contribution order.
  List<TimelineMemory> memoriesFor(String tripId);

  /// Adds a memory to [tripId], replacing any existing memory with the same id.
  Future<void> addMemory(String tripId, TimelineMemory memory);

  /// Replaces the memory with the same id on [tripId] (adds it when absent).
  Future<void> updateMemory(String tripId, TimelineMemory memory);

  /// Removes the memory with [memoryId] from [tripId].
  Future<void> deleteMemory(String tripId, String memoryId);

  /// The latest lyric draft for [tripId], or null when the song has not been
  /// written yet.
  LyricSong? songFor(String tripId);

  /// Persists [song] as the lyric draft of [tripId], replacing any previous
  /// draft. Hand edits and rewrites survive restarts through this seam.
  Future<void> saveSong(String tripId, LyricSong song);
}

/// Fast, in-memory implementation of [TripStore] for tests and transient
/// sessions. Construct it with preset [trips]/[activeTripId] to start a test
/// from an already-populated trip.
class InMemoryTripStore extends ChangeNotifier implements TripStore {
  final List<Trip> _trips = [];
  String? _activeTripId;

  InMemoryTripStore({List<Trip> trips = const [], String? activeTripId}) {
    _trips.addAll(trips);
    _activeTripId = activeTripId;
  }

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
  Future<void> init() async {}

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
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final trip = _trips[index];
      final updatedCrew = List<CrewMember>.from(trip.crew);
      final existingIndex = updatedCrew.indexWhere((c) => c.id == member.id);
      if (existingIndex != -1) {
        updatedCrew[existingIndex] = member;
      } else {
        updatedCrew.add(member);
      }
      _trips[index] = trip.copyWith(crew: updatedCrew);
      notifyListeners();
    }
  }

  @override
  List<TimelineMemory> memoriesFor(String tripId) {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return const [];
    return List.unmodifiable(_trips[index].memories);
  }

  /// Applies [mutate] to a trip's memories and returns true when it changed.
  bool _mutateMemories(
    String tripId,
    List<TimelineMemory> Function(List<TimelineMemory> current) mutate,
  ) {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return false;
    final updated = mutate(List<TimelineMemory>.from(_trips[index].memories));
    _trips[index] = _trips[index].copyWith(memories: updated);
    notifyListeners();
    return true;
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
      final index = current.indexWhere((m) => m.id == memory.id);
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
}

/// SharedPreferences-backed [TripStore] that serializes trips (including crew
/// and memories) to JSON, allowing them to survive app restarts.
class PreferencesTripStore extends ChangeNotifier implements TripStore {
  static const String _tripsKey = 'road_song_saved_trips_v1';
  static const String _activeTripKey = 'road_song_active_trip_id_v1';

  final List<Trip> _trips = [];
  String? _activeTripId;
  bool _initialized = false;

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
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_tripsKey) ?? [];
    _trips.clear();
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _trips.add(Trip.fromJson(map));
      } catch (_) {}
    }
    _activeTripId = prefs.getString(_activeTripKey);
    _initialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = _trips.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_tripsKey, rawList);
    if (_activeTripId != null) {
      await prefs.setString(_activeTripKey, _activeTripId!);
    } else {
      await prefs.remove(_activeTripKey);
    }
  }

  @override
  Future<void> addTrip(Trip trip) async {
    if (!_initialized) await init();
    _trips.removeWhere((t) => t.id == trip.id);
    _trips.add(trip);
    _activeTripId = trip.id;
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> setActiveTrip(String tripId) async {
    if (!_initialized) await init();
    if (_trips.any((t) => t.id == tripId)) {
      _activeTripId = tripId;
      await _persist();
      notifyListeners();
    }
  }

  @override
  Future<void> addCrewMember(String tripId, CrewMember member) async {
    if (!_initialized) await init();
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final trip = _trips[index];
      final updatedCrew = List<CrewMember>.from(trip.crew);
      final existingIndex = updatedCrew.indexWhere((c) => c.id == member.id);
      if (existingIndex != -1) {
        updatedCrew[existingIndex] = member;
      } else {
        updatedCrew.add(member);
      }
      _trips[index] = trip.copyWith(crew: updatedCrew);
      await _persist();
      notifyListeners();
    }
  }

  @override
  List<TimelineMemory> memoriesFor(String tripId) {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return const [];
    return List.unmodifiable(_trips[index].memories);
  }

  Future<void> _mutateMemories(
    String tripId,
    List<TimelineMemory> Function(List<TimelineMemory> current) mutate,
  ) async {
    if (!_initialized) await init();
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;
    final updated = mutate(List<TimelineMemory>.from(_trips[index].memories));
    _trips[index] = _trips[index].copyWith(memories: updated);
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> addMemory(String tripId, TimelineMemory memory) {
    return _mutateMemories(tripId, (current) {
      current.removeWhere((m) => m.id == memory.id);
      current.add(memory);
      return current;
    });
  }

  @override
  Future<void> updateMemory(String tripId, TimelineMemory memory) {
    return _mutateMemories(tripId, (current) {
      final index = current.indexWhere((m) => m.id == memory.id);
      if (index == -1) {
        current.add(memory);
      } else {
        current[index] = memory;
      }
      return current;
    });
  }

  @override
  Future<void> deleteMemory(String tripId, String memoryId) {
    return _mutateMemories(
      tripId,
      (current) => current..removeWhere((m) => m.id == memoryId),
    );
  }

  @override
  LyricSong? songFor(String tripId) {
    final int index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return null;
    return _trips[index].song;
  }

  @override
  Future<void> saveSong(String tripId, LyricSong song) async {
    if (!_initialized) await init();
    final int index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;
    _trips[index] = _trips[index].copyWith(song: song);
    await _persist();
    notifyListeners();
  }
}
