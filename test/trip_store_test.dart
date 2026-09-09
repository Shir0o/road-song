import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleTrip = Trip(
    id: 'trip-101',
    name: 'Pacific Coast Highway',
    firstDay: 'SEP 10',
    lastDay: 'SEP 15',
    coverIndex: 2,
    crew: const [
      CrewMember(
        id: 'user-1',
        name: 'Jordan Lee',
        handle: '@jordan',
        initial: 'J',
        color: Color(0xFF3E6B8A),
        invited: true,
      ),
    ],
    sessionLink: 'roadsong.app/t/pacific-coast-highway',
    createdAt: DateTime(2026, 9, 8, 12, 0),
  );

  group('Trip JSON serialization', () {
    test('round-trips Trip and CrewMember through toJson and fromJson', () {
      final json = sampleTrip.toJson();
      final restored = Trip.fromJson(json);

      expect(restored.id, sampleTrip.id);
      expect(restored.name, sampleTrip.name);
      expect(restored.firstDay, sampleTrip.firstDay);
      expect(restored.lastDay, sampleTrip.lastDay);
      expect(restored.coverIndex, sampleTrip.coverIndex);
      expect(restored.sessionLink, sampleTrip.sessionLink);
      expect(restored.createdAt, sampleTrip.createdAt);
      expect(restored.crew.length, 1);
      expect(restored.crew.first.name, 'Jordan Lee');
      expect(restored.crew.first.invited, true);
      expect(restored.crew.first.color.toARGB32(), const Color(0xFF3E6B8A).toARGB32());
    });
  });

  group('InMemoryTripStore', () {
    test('creates and retrieves trips', () async {
      final store = InMemoryTripStore();
      expect(store.trips, isEmpty);
      expect(store.activeTrip, isNull);

      await store.addTrip(sampleTrip);
      expect(store.trips.length, 1);
      expect(store.trips.first.name, 'Pacific Coast Highway');
      expect(store.activeTrip?.name, 'Pacific Coast Highway');
    });

    test('updates active trip selection', () async {
      final store = InMemoryTripStore();
      final trip2 = Trip(
        id: 'trip-102',
        name: 'Route 66',
        firstDay: 'OCT 1',
        lastDay: 'OCT 5',
        coverIndex: 0,
        crew: const [],
        sessionLink: 'roadsong.app/t/route-66',
        createdAt: DateTime(2026, 10, 1),
      );

      await store.addTrip(sampleTrip);
      await store.addTrip(trip2);
      expect(store.activeTrip?.id, 'trip-102');

      await store.setActiveTrip('trip-101');
      expect(store.activeTrip?.id, 'trip-101');
    });

    test('adds crew members to trip', () async {
      final store = InMemoryTripStore();
      await store.addTrip(sampleTrip);

      const newMember = CrewMember(
        id: 'user-2',
        name: 'Taylor Swift',
        handle: '@taylor',
        initial: 'T',
        color: Color(0xFFC05B3E),
        invited: true,
      );

      await store.addCrewMember('trip-101', newMember);
      final trip = store.trips.firstWhere((t) => t.id == 'trip-101');
      expect(trip.crew.length, 2);
      expect(trip.crew.map((c) => c.name), contains('Taylor Swift'));
    });
  });

  group('PreferencesTripStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists trips and survives store reload', () async {
      final store1 = PreferencesTripStore();
      await store1.init();
      expect(store1.trips, isEmpty);
      expect(store1.activeTrip, isNull);

      await store1.addTrip(sampleTrip);
      expect(store1.trips.length, 1);
      expect(store1.activeTrip?.id, 'trip-101');

      // Simulate full app restart by creating a fresh store reading the same prefs
      final store2 = PreferencesTripStore();
      await store2.init();
      expect(store2.trips.length, 1);
      expect(store2.trips.first.name, 'Pacific Coast Highway');
      expect(store2.activeTrip?.id, 'trip-101');
      expect(store2.trips.first.crew.first.name, 'Jordan Lee');
    });

    test('persists crew additions', () async {
      final store1 = PreferencesTripStore();
      await store1.init();
      await store1.addTrip(sampleTrip);

      const newMember = CrewMember(
        id: 'user-2',
        name: 'Alex Rivera',
        handle: '@alex',
        initial: 'A',
        color: Color(0xFF7D8663),
        invited: true,
      );

      await store1.addCrewMember('trip-101', newMember);

      // Reload in fresh instance
      final store2 = PreferencesTripStore();
      await store2.init();
      expect(store2.activeTrip?.crew.length, 2);
      expect(store2.activeTrip?.crew.any((c) => c.name == 'Alex Rivera'), isTrue);
    });
  });
}
