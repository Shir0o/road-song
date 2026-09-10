import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/services/remote_trip_store.dart';

import 'fake_backend.dart';

/// Store-client contract suite: drives the client against the fake backend
/// (same HTTP contract as the hosted Worker) — no real network in CI.
///
/// Covers: create trip, fetch trip, add memory, trip-code scope enforcement
/// (cross-trip access denied), upload guardrail rejection, and retry after a
/// simulated drop.
void main() {
  group('TripStoreClient contract (fake backend)', () {
    late FakeBackend backend;

    setUp(() {
      backend = FakeBackend();
    });

    test('createTrip returns a trip with a code-shaped link', () async {
      final Trip trip = await backend.createTrip(
        const TripDraft(
          name: 'Lisbon Trip',
          firstDay: 'JUN 12',
          lastDay: 'JUN 18',
        ),
      );
      expect(trip.name, 'Lisbon Trip');
      expect(trip.code, isNotEmpty);
      expect(trip.sessionLink, 'roadsong.app/t/${trip.code}');
      expect(trip.memories, isEmpty);
    });

    test('fetchTrip returns the trip with its memories in order', () async {
      final Trip trip = await backend.createTrip(
        const TripDraft(name: 'Lisbon Trip'),
      );
      await backend.createMemory(
        trip.code,
        TimelineMemory(
          id: 'm1',
          author: '@maya',
          contributor: 'Maya',
          time: '10:00 AM',
          text: 'First lore',
          type: MemoryType.text,
          createdAt: DateTime(2026, 6, 12, 10),
        ),
      );
      await backend.createMemory(
        trip.code,
        TimelineMemory(
          id: 'm2',
          author: '@tom',
          contributor: 'Tom',
          time: '11:00 AM',
          text: 'Second lore',
          type: MemoryType.text,
          createdAt: DateTime(2026, 6, 12, 11),
        ),
      );

      final Trip fetched = await backend.fetchTrip(trip.code);
      expect(fetched.memories.map((m) => m.text), [
        'First lore',
        'Second lore',
      ]);
    });

    test('fetchTrip with an unknown code is a 404', () async {
      expect(
        () => backend.fetchTrip('nope'),
        throwsA(
          isA<TripStoreHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test(
      'trip-code scope: memories are only reachable under their own code',
      () async {
        final Trip alpha = await backend.createTrip(
          const TripDraft(name: 'Alpha Trip'),
        );
        final Trip bravo = await backend.createTrip(
          const TripDraft(name: 'Bravo Trip'),
        );
        await backend.createMemory(
          alpha.code,
          TimelineMemory(
            id: 'mem-alpha',
            author: '@maya',
            contributor: 'Maya',
            time: '10:00 AM',
            text: 'Alpha lore',
            type: MemoryType.text,
          ),
        );

        // Bravo's code never sees alpha's memory.
        final Trip bravoFetched = await backend.fetchTrip(bravo.code);
        expect(bravoFetched.memories, isEmpty);

        // Deleting alpha's memory under bravo's code is denied.
        backend.rejectDeleteMemoryWithStatus = 404;
        expect(
          () => backend.deleteMemory(bravo.code, 'mem-alpha'),
          throwsA(
            isA<TripStoreHttpException>().having(
              (e) => e.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
        // The memory is still there under its own code.
        expect(
          (await backend.fetchTrip(alpha.code)).memories.map((m) => m.id),
          ['mem-alpha'],
        );
      },
    );

    test(
      'upload guardrail: oversized photos and videos are rejected with 413',
      () async {
        final Trip trip = await backend.createTrip(
          const TripDraft(name: 'Guardrail Trip'),
        );

        backend.rejectUploadUrlWithStatus = 413;
        expect(
          () => backend.requestUploadUrl(
            tripCode: trip.code,
            type: 'photo',
            contentType: 'image/jpeg',
            contentLength: 12 * 1024 * 1024 + 1,
          ),
          throwsA(
            isA<TripStoreHttpException>().having(
              (e) => e.statusCode,
              'statusCode',
              413,
            ),
          ),
        );

        backend.rejectUploadUrlWithStatus = 413;
        expect(
          () => backend.requestUploadUrl(
            tripCode: trip.code,
            type: 'video',
            contentType: 'video/mp4',
            contentLength: 64 * 1024 * 1024 + 1,
          ),
          throwsA(
            isA<TripStoreHttpException>().having(
              (e) => e.statusCode,
              'statusCode',
              413,
            ),
          ),
        );

        // In-limit files pass.
        final urls = await backend.requestUploadUrl(
          tripCode: trip.code,
          type: 'photo',
          contentType: 'image/jpeg',
          contentLength: 1000,
        );
        expect(urls.mediaKey, startsWith('trips/'));
      },
    );

    test('media memory requires the object to exist before creation', () async {
      final Trip trip = await backend.createTrip(
        const TripDraft(name: 'Media Trip'),
      );
      expect(
        () => backend.createMemory(
          trip.code,
          TimelineMemory(
            id: 'm',
            author: '@maya',
            contributor: 'Maya',
            time: '10:00 AM',
            text: '',
            type: MemoryType.photo,
          ),
          mediaKey: 'trips/${trip.id}/never-uploaded.jpg',
        ),
        throwsA(
          isA<TripStoreHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
    });

    test('media key from another trip is rejected', () async {
      final Trip alpha = await backend.createTrip(
        const TripDraft(name: 'Alpha Trip'),
      );
      final Trip bravo = await backend.createTrip(
        const TripDraft(name: 'Bravo Trip'),
      );
      expect(
        () => backend.createMemory(
          alpha.code,
          TimelineMemory(
            id: 'm',
            author: '@maya',
            contributor: 'Maya',
            time: '10:00 AM',
            text: '',
            type: MemoryType.photo,
          ),
          mediaKey: 'trips/${bravo.id}/foreign.jpg',
        ),
        throwsA(
          isA<TripStoreHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
    });

    test(
      'uploadGuestMemory succeeds end to end and reports progress',
      () async {
        final Trip trip = await backend.createTrip(
          const TripDraft(name: 'Upload Trip'),
        );
        final RemoteTripStore store = RemoteTripStore(client: backend);

        final List<double> progress = [];
        final TripUploadResult result = await uploadGuestMemoryTo(
          backend,
          tripCode: trip.code,
          contributor: 'Maya',
          author: '@maya',
          type: MemoryType.photo,
          bytes: Uint8List.fromList(const [1, 2, 3]),
          contentType: 'image/jpeg',
          caption: 'the churro incident',
          onProgress: progress.add,
        );

        expect(result.isSuccess, isTrue);
        expect(progress, isNotEmpty);
        expect(progress.last, 1.0);
        expect(
          (await backend.fetchTrip(trip.code)).memories.single.caption,
          'the churro incident',
        );
        expect(store.trips, isEmpty); // the store itself was untouched
      },
    );

    test(
      'retry after a simulated drop: first attempt fails, retry succeeds',
      () async {
        final Trip trip = await backend.createTrip(
          const TripDraft(name: 'Flaky Trip'),
        );

        backend.simulateNextUploadDrop = true;
        final TripUploadResult first = await uploadGuestMemoryTo(
          backend,
          tripCode: trip.code,
          contributor: 'Maya',
          author: '@maya',
          type: MemoryType.photo,
          bytes: Uint8List.fromList(const [1, 2, 3]),
          contentType: 'image/jpeg',
        );
        expect(first.isSuccess, isFalse);
        expect(first.error, isNotNull);
        // Nothing was created on the backend.
        expect((await backend.fetchTrip(trip.code)).memories, isEmpty);

        // Retry succeeds and the memory lands.
        final TripUploadResult retry = await uploadGuestMemoryTo(
          backend,
          tripCode: trip.code,
          contributor: 'Maya',
          author: '@maya',
          type: MemoryType.photo,
          bytes: Uint8List.fromList(const [1, 2, 3]),
          contentType: 'image/jpeg',
        );
        expect(retry.isSuccess, isTrue);
        expect((await backend.fetchTrip(trip.code)).memories, hasLength(1));
      },
    );

    test(
      'RemoteTripStore polls and merges new guest memories without restart',
      () async {
        final Trip trip = await backend.createTrip(
          const TripDraft(name: 'Poll Trip'),
        );
        final RemoteTripStore store = RemoteTripStore(
          client: backend,
          pollInterval: const Duration(milliseconds: 50),
        );
        await store.addTrip(trip);
        await store.init();
        addTearDown(store.dispose);

        expect(store.memoriesFor(trip.id), isEmpty);

        // A guest adds a memory on the backend (another device).
        await backend.createMemory(
          trip.code,
          TimelineMemory(
            id: 'guest-1',
            author: '@priya',
            contributor: 'Priya',
            time: '10:00 AM',
            text: 'Guest lore from the web',
            type: MemoryType.text,
            createdAt: DateTime(2026, 6, 12, 10),
          ),
        );

        // The next poll merges it into the local mirror — no restart needed.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(
          store.memoriesFor(trip.id).map((m) => m.text),
          contains('Guest lore from the web'),
        );
      },
    );

    test('a failed poll is silent and the next tick recovers', () async {
      final Trip trip = await backend.createTrip(
        const TripDraft(name: 'Recover Trip'),
      );
      final RemoteTripStore store = RemoteTripStore(
        client: backend,
        pollInterval: const Duration(milliseconds: 50),
      );
      await store.addTrip(trip);
      await store.init();
      addTearDown(store.dispose);

      backend.simulateNextFetchFailure = true;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      // The failed poll changed nothing; a later successful poll merges.
      await backend.createMemory(
        trip.code,
        TimelineMemory(
          id: 'guest-2',
          author: '@tom',
          contributor: 'Tom',
          time: '11:00 AM',
          text: 'Recovered lore',
          type: MemoryType.text,
          createdAt: DateTime(2026, 6, 12, 11),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        store.memoriesFor(trip.id).map((m) => m.text),
        contains('Recovered lore'),
      );
    });

    test('tripCodeFromLink parses the roadsong.app/t/<code> shape', () {
      expect(tripCodeFromLink('roadsong.app/t/lisbon-trip'), 'lisbon-trip');
      expect(
        tripCodeFromLink('https://roadsong.app/t/lisbon-trip'),
        'lisbon-trip',
      );
      expect(tripCodeFromLink('/t/lisbon-trip'), 'lisbon-trip');
      expect(tripCodeFromLink('lisbon-trip'), 'lisbon-trip');
      expect(tripCodeFromLink(''), isNull);
      expect(tripCodeFromLink('https://example.com/other'), isNull);
      expect(buildTripLink('lisbon-trip'), 'roadsong.app/t/lisbon-trip');
    });

    test('publishSong stores the memorial and fetchSong serves it', () async {
      final Trip trip = await backend.createTrip(
        const TripDraft(name: 'Memorial Trip'),
      );
      const MemorialSong song = MemorialSong(
        title: 'Every Wrong Turn',
        styleId: 'pop-punk',
        bpm: 168,
        audioAsset: 'audio/vibes/pop_punk.mp3',
        durationMs: 8000,
        lyrics: ['Press play on the tapes,', 'Sing it back on the long road,'],
        sections: [
          MemorialSection(
            id: 'intro',
            label: 'Intro',
            kind: 'intro',
            startMs: 0,
            endMs: 2000,
            lines: [MemorialLine(text: 'Press play on the tapes,', startMs: 0)],
          ),
        ],
      );

      final MemorialSong published = await backend.publishSong(trip.code, song);
      expect(published.title, 'Every Wrong Turn');

      final MemorialSong? served = await backend.fetchSong(trip.code);
      expect(served, isNotNull);
      expect(served!.styleId, 'pop-punk');
      expect(served.audioAsset, 'audio/vibes/pop_punk.mp3');
      expect(served.lyrics, hasLength(2));
      expect(served.sections.single.lines.single.startMs, 0);

      // The trip fetch carries the memorial for the visitor surface.
      final Trip fetched = await backend.fetchTrip(trip.code);
      expect(fetched.memorialSong?.title, 'Every Wrong Turn');
    });

    test('fetchSong is null before the memorial is published', () async {
      final Trip trip = await backend.createTrip(
        const TripDraft(name: 'No Song Trip'),
      );
      expect(await backend.fetchSong(trip.code), isNull);
      expect((await backend.fetchTrip(trip.code)).memorialSong, isNull);
    });

    test('RemoteTripStore.publishMemorialSong mirrors the memorial locally '
        'and the next poll keeps it', () async {
      final Trip trip = await backend.createTrip(
        const TripDraft(name: 'Remote Memorial Trip'),
      );
      final RemoteTripStore store = RemoteTripStore(
        client: backend,
        pollInterval: const Duration(milliseconds: 50),
      );
      await store.addTrip(trip);
      await store.init();
      addTearDown(store.dispose);

      const MemorialSong song = MemorialSong(
        title: 'Every Wrong Turn',
        styleId: 'sad-boy-indie',
        bpm: 92,
        audioAsset: 'audio/vibes/sad_boy_indie.mp3',
        durationMs: 8000,
        lyrics: ['Press play on the tapes,'],
        sections: [
          MemorialSection(
            id: 'intro',
            label: 'Intro',
            kind: 'intro',
            startMs: 0,
            endMs: 2000,
            lines: [MemorialLine(text: 'Press play on the tapes,', startMs: 0)],
          ),
        ],
      );
      await store.publishMemorialSong(trip.id, song);
      expect(store.activeTrip?.memorialSong?.title, 'Every Wrong Turn');

      // A later poll re-fetches the remote trip; the memorial survives.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(store.activeTrip?.memorialSong?.styleId, 'sad-boy-indie');
    });
  });
}
