import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_song/models/song_models.dart';
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
      expect(
        restored.crew.first.color.toARGB32(),
        const Color(0xFF3E6B8A).toARGB32(),
      );
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
      expect(
        store2.activeTrip?.crew.any((c) => c.name == 'Alex Rivera'),
        isTrue,
      );
    });
  });

  group('TimelineMemory JSON serialization', () {
    test('round-trips a photo memory including bytes, caption and pin', () {
      final photoBytes = Uint8List.fromList(const [1, 2, 3, 4, 250]);
      final created = DateTime(2026, 9, 10, 11, 42);
      final memory = TimelineMemory(
        id: 'mem-photo',
        author: '@you',
        contributor: 'You',
        time: '11:42 AM',
        text: 'The churro incident.',
        caption: 'the churro incident',
        type: MemoryType.photo,
        createdAt: created,
        day: 2,
        dayDate: 'SEP 11',
        locationName: 'Marina Pier',
        latitude: 22.8892,
        longitude: -109.9112,
        likes: 4,
        likedByMe: true,
        photoBytes: photoBytes,
        rotationDegrees: -2.0,
      );

      final restored = TimelineMemory.fromJson(memory.toJson());

      expect(restored.id, 'mem-photo');
      expect(restored.author, '@you');
      expect(restored.contributor, 'You');
      expect(restored.text, memory.text);
      expect(restored.caption, 'the churro incident');
      expect(restored.type, MemoryType.photo);
      expect(restored.createdAt, created);
      expect(restored.day, 2);
      expect(restored.dayDate, 'SEP 11');
      expect(restored.locationName, 'Marina Pier');
      expect(restored.latitude, 22.8892);
      expect(restored.longitude, -109.9112);
      expect(restored.likes, 4);
      expect(restored.likedByMe, isTrue);
      expect(restored.photoBytes, photoBytes);
      expect(restored.rotationDegrees, -2.0);
    });

    test('round-trips a pinned video memory with a null lat/lng slot', () {
      final videoBytes = Uint8List.fromList(List.filled(2048, 7));
      final memory = TimelineMemory(
        id: 'mem-video',
        author: '@you',
        time: '1:05 PM',
        text: 'Tram 28, all five of us.',
        type: MemoryType.video,
        videoBytes: videoBytes,
        locationName: 'Rua Garrett, Lisbon',
        day: 1,
      );

      final restored = TimelineMemory.fromJson(memory.toJson());

      expect(restored.type, MemoryType.video);
      expect(restored.hasVideo, isTrue);
      expect(restored.videoBytes, videoBytes);
      expect(restored.isPinned, isTrue);
      expect(restored.latitude, isNull);
      expect(restored.longitude, isNull);
      expect(restored.caption, '');
      expect(restored.displayContributor, '@you');
    });

    test('derives the media type when only media is attached', () {
      const textOnly = TimelineMemory(
        id: 'mem-text',
        author: '@you',
        time: '10:00 AM',
        text: 'Lore only',
      );
      expect(textOnly.type, MemoryType.text);

      final photo = textOnly.copyWith(
        photoBytes: Uint8List.fromList(const [9]),
      );
      expect(photo.type, MemoryType.photo);
    });
  });

  group('TripStore memory CRUD', () {
    TimelineMemory memoryFixture(
      String id, {
      MemoryType type = MemoryType.text,
    }) {
      return TimelineMemory(
        id: id,
        author: '@you',
        contributor: 'You',
        time: '10:00 AM',
        text: 'Note $id',
        type: type,
        photoBytes: type == MemoryType.photo
            ? Uint8List.fromList(const [1, 2, 3])
            : null,
        videoBytes: type == MemoryType.video
            ? Uint8List.fromList(const [4, 5, 6])
            : null,
        createdAt: DateTime(2026, 9, 10),
        day: 1,
        dayDate: 'SEP 10',
      );
    }

    test('is constructible with preset trips and memories', () {
      final store = InMemoryTripStore(
        trips: [
          sampleTrip.copyWith(memories: [memoryFixture('mem-1')]),
        ],
        activeTripId: 'trip-101',
      );

      expect(store.activeTrip?.id, 'trip-101');
      expect(store.memoriesFor('trip-101').single.text, 'Note mem-1');
    });

    test('adds, updates and deletes memories on a trip', () async {
      final store = InMemoryTripStore(trips: [sampleTrip]);
      expect(store.memoriesFor('trip-101'), isEmpty);
      expect(store.memoriesFor('missing-trip'), isEmpty);

      await store.addMemory('trip-101', memoryFixture('mem-1'));
      await store.addMemory(
        'trip-101',
        memoryFixture('mem-2', type: MemoryType.photo),
      );
      expect(store.memoriesFor('trip-101').map((m) => m.id), [
        'mem-1',
        'mem-2',
      ]);

      await store.updateMemory(
        'trip-101',
        store
            .memoriesFor('trip-101')
            .first
            .copyWith(caption: 'fixed the caption', contributor: 'Maya'),
      );
      final updated = store.memoriesFor('trip-101').first;
      expect(updated.displayCaption, 'fixed the caption');
      expect(updated.displayContributor, 'Maya');

      await store.deleteMemory('trip-101', 'mem-1');
      expect(store.memoriesFor('trip-101').map((m) => m.id), ['mem-2']);

      // Operations on an unknown trip change nothing.
      await store.addMemory('nope', memoryFixture('mem-3'));
      await store.deleteMemory('nope', 'mem-3');
      expect(store.memoriesFor('nope'), isEmpty);
    });

    test('notifies listeners when memories change', () async {
      final store = InMemoryTripStore(trips: [sampleTrip]);
      int notifications = 0;
      store.addListener(() => notifications++);

      await store.addMemory('trip-101', memoryFixture('mem-1'));
      await store.deleteMemory('trip-101', 'mem-1');

      expect(notifications, 2);
    });

    test('persists memories with media bytes across a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final store1 = PreferencesTripStore();
      await store1.init();
      await store1.addTrip(sampleTrip);

      final videoBytes = Uint8List.fromList(List.filled(1024, 11));
      await store1.addMemory(
        'trip-101',
        TimelineMemory(
          id: 'mem-video',
          author: '@you',
          contributor: 'You',
          time: '1:00 PM',
          text: 'Short clip of the wrong hill',
          type: MemoryType.video,
          videoBytes: videoBytes,
          locationName: 'Sintra, the wrong hill',
          createdAt: DateTime(2026, 9, 10),
          day: 1,
        ),
      );

      final store2 = PreferencesTripStore();
      await store2.init();
      final restored = store2.memoriesFor('trip-101').single;
      expect(restored.type, MemoryType.video);
      expect(restored.videoBytes, videoBytes);
      expect(restored.locationName, 'Sintra, the wrong hill');
      expect(restored.latitude, isNull);
      expect(restored.createdAt, DateTime(2026, 9, 10));

      await store2.deleteMemory('trip-101', 'mem-video');

      final store3 = PreferencesTripStore();
      await store3.init();
      expect(store3.memoriesFor('trip-101'), isEmpty);
    });
  });

  group('TripStore lyric draft seam', () {
    const LyricSong kDraft = LyricSong(
      title: 'Every Wrong Turn',
      sections: <LyricSection>[
        LyricSection(
          id: 'ch',
          label: 'Chorus',
          variants: <List<String>>[
            ['Sing it back on the long road,', 'every wrong turn worth it.'],
          ],
        ),
      ],
    );

    test('songFor is null until a draft is saved', () async {
      final store = InMemoryTripStore(trips: [sampleTrip]);
      expect(store.songFor('trip-101'), isNull);
      expect(store.songFor('missing-trip'), isNull);
    });

    test('saveSong replaces the previous draft', () async {
      final store = InMemoryTripStore(trips: [sampleTrip]);
      await store.saveSong('trip-101', kDraft);
      expect(store.songFor('trip-101')!.title, 'Every Wrong Turn');
      expect(store.songFor('trip-101')!.section('ch')!.lines, [
        'Sing it back on the long road,',
        'every wrong turn worth it.',
      ]);

      const LyricSong edited = LyricSong(
        title: 'Every Wrong Turn',
        sections: <LyricSection>[
          LyricSection(
            id: 'ch',
            label: 'Chorus',
            variants: <List<String>>[
              ['Hand-edited chorus line'],
            ],
          ),
        ],
      );
      await store.saveSong('trip-101', edited);
      expect(store.songFor('trip-101')!.section('ch')!.lines, [
        'Hand-edited chorus line',
      ]);
    });

    test('saving to an unknown trip changes nothing', () async {
      final store = InMemoryTripStore(trips: [sampleTrip]);
      await store.saveSong('nope', kDraft);
      expect(store.songFor('nope'), isNull);
    });

    test('a lyric draft survives a PreferencesTripStore restart', () async {
      SharedPreferences.setMockInitialValues({});
      final store1 = PreferencesTripStore();
      await store1.init();
      await store1.addTrip(sampleTrip);
      await store1.saveSong('trip-101', kDraft);

      final store2 = PreferencesTripStore();
      await store2.init();
      final LyricSong? restored = store2.songFor('trip-101');
      expect(restored, isNotNull);
      expect(restored!.title, 'Every Wrong Turn');
      expect(restored.section('ch')!.lines, [
        'Sing it back on the long road,',
        'every wrong turn worth it.',
      ]);
    });

    test('a lyric draft round-trips through Trip JSON', () async {
      final json = sampleTrip.copyWith(song: kDraft).toJson();
      final restored = Trip.fromJson(json);
      expect(restored.song!.title, 'Every Wrong Turn');
      expect(restored.song!.section('ch')!.lines, [
        'Sing it back on the long road,',
        'every wrong turn worth it.',
      ]);
    });
  });
}
