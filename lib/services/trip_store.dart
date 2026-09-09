import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_models.dart';

/// Abstract storage seam for trip creation, persistence, and retrieval.
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
}

/// Fast, in-memory implementation of [TripStore] for tests and transient sessions.
class InMemoryTripStore extends ChangeNotifier implements TripStore {
  final List<Trip> _trips = [];
  String? _activeTripId;

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
}

/// SharedPreferences-backed [TripStore] that serializes trip metadata to JSON,
/// allowing trips and crew members to survive app restarts.
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
}
