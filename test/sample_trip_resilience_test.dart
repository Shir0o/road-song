import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_song/main.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/screens/guest_portal_screen.dart';
import 'package:road_song/services/audio_seam.dart';
import 'package:road_song/services/pending_upload_store.dart';
import 'package:road_song/services/sample_trip.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

/// A fake audio seam for the sample-trip player (mocked in CI).
class FakeAudioSeam implements AudioSeam {
  final List<String> primed = [];
  final List<String> started = [];
  int stopCount = 0;
  int pauseCount = 0;
  final StreamController<Duration> positions = StreamController.broadcast();
  final StreamController<Duration> durations = StreamController.broadcast();
  final StreamController<void> completes = StreamController.broadcast();

  @override
  Future<void> prime(String asset) async {
    primed.add(asset);
  }

  @override
  Future<void> start() async {
    started.add(primed.isEmpty ? '' : primed.last);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Stream<Duration> get durationStream => durations.stream;

  @override
  Stream<void> get onComplete => completes.stream;
}

/// 1x1 transparent PNG — a decodable photo fixture for guest uploads.
const List<int> kPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('Sample trip (issue #31)', () {
    testWidgets(
      'first launch offers fresh vs sample; the sample demos the full arc '
      'through the real screens',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final audio = FakeAudioSeam();

        await tester.pumpWidget(RoadSongApp(audioSeam: audio));
        await tester.pumpAndSettle();

        // First launch (no trip yet): fresh vs sample are both offered.
        expect(find.text('Start a trip song'), findsOneWidget);
        expect(find.byKey(const ValueKey('load-sample-trip')), findsOneWidget);

        // Load the sample: it lands on the trip hub through the store seam.
        await tester.tap(find.byKey(const ValueKey('load-sample-trip')));
        await tester.pumpAndSettle();
        expect(find.text('LISBON → PORTO'), findsOneWidget);

        // Diary: multiple contributors, mixed media, day grouping.
        expect(find.text('Day 1'), findsOneWidget);
        expect(find.text('Day 2'), findsOneWidget);
        expect(find.text('Maya'), findsOneWidget);
        expect(find.text('Tom'), findsOneWidget);
        expect(find.text('Priya'), findsOneWidget);
        expect(find.text('tram 28, all five of us'), findsOneWidget);
        expect(find.byKey(const ValueKey('clip-sample-video')), findsOneWidget);
        expect(
          find.text('The wrong hill, Sintra. Never again.'),
          findsOneWidget,
        );

        // Route: pinned places along the route.
        await tester.tap(find.byIcon(Icons.flag));
        await tester.pumpAndSettle();
        expect(find.text('The route'), findsOneWidget);
        expect(find.textContaining('3 stops'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('route-pin-sample-photo')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('route-pin-sample-text-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('route-pin-sample-video')),
          findsOneWidget,
        );

        // Song: the finished song resumes at the ready stage.
        await tester.tap(find.byIcon(Icons.music_note));
        await tester.pumpAndSettle();
        expect(find.text('Your song is ready!'), findsOneWidget);
        expect(find.text('mastered at 168 BPM · Pop-Punk'), findsOneWidget);

        // Lyrics are one tap away, editable, and show the saved status.
        await tester.tap(find.byKey(const ValueKey('sound-back')));
        await tester.pump();
        expect(find.text('Every Wrong Turn'), findsOneWidget);
        expect(find.textContaining('saved ✓'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('edit-ch')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('edit-field')),
          'Our chorus, hand-written\nLine two of the chorus',
        );
        await tester.tap(find.byKey(const ValueKey('save-edit')));
        await tester.pump();
        expect(find.text('Our chorus, hand-written'), findsOneWidget);

        // Making Song is demoable: remix re-runs the staged pass.
        await tester.tap(find.byKey(const ValueKey('choose-sound')));
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('style-card-sad-boy-indie')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('make-song')));
        await tester.pump();
        expect(find.text('Writing lyrics'), findsWidgets);
        await tester.pump(const Duration(milliseconds: 4500));
        await tester.pump();
        expect(find.text('Your song is ready!'), findsOneWidget);

        // Player: the finished memorial plays.
        await tester.tap(find.byKey(const ValueKey('play-song')));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('kinetic-play-pause-button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('kinetic-close-button')));
        await tester.pump();
        expect(find.text('Your song is ready!'), findsOneWidget);

        // Share: the memorial ready moment with the trip link.
        await tester.tap(find.byKey(const ValueKey('share-memorial-link')));
        await tester.pump();
        expect(find.text('Your trip memorial is ready'), findsOneWidget);
        expect(find.text('roadsong.app/t/lisbon-porto'), findsOneWidget);
      },
    );

    testWidgets('the sample trip survives a restart and resumes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      final store1 = TripStore.persistent();
      await store1.init();
      await store1.addTrip(buildSampleTrip());
      final audio = FakeAudioSeam();

      await tester.pumpWidget(RoadSongApp(tripStore: store1, audioSeam: audio));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();
      expect(find.text('LISBON → PORTO'), findsOneWidget);

      // Restart: a fresh store reads the same preferences.
      final store2 = TripStore.persistent();
      await store2.init();
      expect(store2.trips.single.name, 'Lisbon → Porto');
      expect(store2.memoriesFor('sample-trip'), hasLength(4));
      expect(store2.songFor('sample-trip'), isNotNull);
      expect(store2.songArtifactFor('sample-trip')?.isUnlocked, isTrue);

      await tester.pumpWidget(
        RoadSongApp(
          key: const ValueKey('restart-sample'),
          tripStore: store2,
          audioSeam: audio,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();

      // The finished song resumes at the ready stage.
      await tester.tap(find.byIcon(Icons.music_note));
      await tester.pumpAndSettle();
      expect(find.text('Your song is ready!'), findsOneWidget);
    });
  });

  group('Lyric draft status (issue #31)', () {
    testWidgets('hand edits show a saved status and survive a restart', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      final store1 = TripStore.persistent();
      await store1.init();
      await store1.addTrip(
        Trip(
          id: 'trip-lyric',
          name: 'Cabo Trip',
          firstDay: 'JAN 7',
          lastDay: 'JAN 12',
          coverIndex: 0,
          crew: const [
            CrewMember(
              id: 'maya',
              name: 'Maya Chen',
              handle: '@maya',
              initial: 'M',
              color: Color(0xFF7D8663),
              invited: true,
            ),
          ],
          sessionLink: 'roadsong.app/t/cabo-trip',
          createdAt: DateTime(2026, 1, 7),
          memories: buildSampleTrip().memories,
        ),
      );

      await tester.pumpWidget(RoadSongApp(tripStore: store1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.music_note));
      await tester.pumpAndSettle();

      // Write our song → lyrics stage.
      await tester.tap(find.text('Write our song'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3400));
      await tester.pump();
      expect(find.text('Every Wrong Turn'), findsOneWidget);

      // Hand-edit the chorus: the saved status appears.
      await tester.tap(find.byKey(const ValueKey('edit-ch')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('edit-field')),
        'Our chorus, hand-written\nLine two of the chorus',
      );
      await tester.tap(find.byKey(const ValueKey('save-edit')));
      await tester.pump();
      expect(find.text('Our chorus, hand-written'), findsOneWidget);
      expect(find.textContaining('saved ✓'), findsOneWidget);

      // Restart: a fresh store reads the same preferences.
      final store2 = TripStore.persistent();
      await store2.init();
      expect(store2.songFor('trip-lyric'), isNotNull);

      await tester.pumpWidget(
        RoadSongApp(key: const ValueKey('restart-lyric'), tripStore: store2),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.music_note));
      await tester.pumpAndSettle();

      // The edit survived and the saved status is visible again.
      expect(find.text('Our chorus, hand-written'), findsOneWidget);
      expect(find.text('Line two of the chorus'), findsOneWidget);
      expect(find.textContaining('saved ✓'), findsOneWidget);
    });
  });

  group('Pending uploads (issue #31)', () {
    Future<FakeBackend> pumpGuestPortal(
      WidgetTester tester, {
      required String tripCode,
      FakeBackend? backend,
      Key? key,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FakeBackend fake = backend ?? FakeBackend();
      final Trip trip = await fake.createTrip(
        const TripDraft(name: 'Lisbon Trip'),
      );
      if (backend == null) tripCode = trip.code;

      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/t/$tripCode';
      addTearDown(
        () => tester.binding.platformDispatcher.defaultRouteNameTestValue = '/',
      );

      await tester.pumpWidget(
        RoadSongApp(
          key: key,
          guestClient: fake,
          guestMediaPickers: GuestMediaPickers(
            photo: () async => Uint8List.fromList(kPng),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets(
      'a simulated drop queues the upload; retry delivers it without data '
      'loss',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final FakeBackend fake = await pumpGuestPortal(tester, tripCode: 'x');
        final String code = fake.trips.single.code;

        await tester.enterText(
          find.byKey(const ValueKey('guest-name')),
          'Maya',
        );
        await tester.tap(find.text('PHOTO'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CHOOSE PHOTO'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('guest-caption')),
          'the churro incident',
        );
        await tester.pump();

        // First attempt: the fake backend drops the connection mid-upload.
        fake.simulateNextUploadDrop = true;
        await tester.ensureVisible(find.byKey(const ValueKey('guest-submit')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('guest-submit')));
        await tester.pumpAndSettle();

        // The upload is queued with a visible status; nothing was lost.
        expect(
          find.byKey(const ValueKey('guest-pending-upload')),
          findsOneWidget,
        );
        expect(find.textContaining('waiting to go through'), findsOneWidget);
        expect(fake.memoriesFor(code), isEmpty);

        // Retry delivers the queued upload.
        await tester.tap(find.byKey(const ValueKey('guest-retry-pending')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('guest-success')), findsOneWidget);
        expect(fake.memoriesFor(code), hasLength(1));
        expect(fake.memoriesFor(code).single.caption, 'the churro incident');
        expect(fake.memoriesFor(code).single.contributor, 'Maya');
        expect(
          find.byKey(const ValueKey('guest-pending-upload')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a queued upload survives a restart with its visible status and '
      'retry',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final FakeBackend fake = await pumpGuestPortal(tester, tripCode: 'x');
        final String code = fake.trips.single.code;

        await tester.enterText(
          find.byKey(const ValueKey('guest-name')),
          'Maya',
        );
        await tester.tap(find.text('PHOTO'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CHOOSE PHOTO'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('guest-caption')),
          'the churro incident',
        );
        await tester.pump();

        // Drop the connection: the upload is queued.
        fake.simulateNextUploadDrop = true;
        await tester.ensureVisible(find.byKey(const ValueKey('guest-submit')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('guest-submit')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('guest-pending-upload')),
          findsOneWidget,
        );

        // Restart: a fresh app instance reads the same preferences.
        await pumpGuestPortal(
          tester,
          tripCode: code,
          backend: fake,
          key: const ValueKey('restart-guest'),
        );

        // The queued upload is re-shown with its visible status.
        expect(
          find.byKey(const ValueKey('guest-pending-upload')),
          findsOneWidget,
        );
        expect(find.textContaining('waiting to go through'), findsOneWidget);
        expect(fake.memoriesFor(code), isEmpty);

        // Retry after the restart delivers the upload.
        await tester.tap(find.byKey(const ValueKey('guest-retry-pending')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('guest-success')), findsOneWidget);
        expect(fake.memoriesFor(code), hasLength(1));
        expect(fake.memoriesFor(code).single.caption, 'the churro incident');
      },
    );

    test('PendingUploadStore round-trips a queued upload', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PendingUploadStore();
      final upload = PendingUpload(
        tripCode: 'lisbon-trip',
        contributor: 'Maya',
        author: '@maya',
        type: MemoryType.photo,
        bytes: Uint8List.fromList(const [1, 2, 3]),
        contentType: 'image/jpeg',
        caption: 'the churro incident',
        text: 'note',
        locationName: 'Marina Pier',
        createdAt: DateTime(2026, 6, 12, 10),
      );
      await store.save(upload);

      final List<PendingUpload> loaded = await store.loadFor('lisbon-trip');
      expect(loaded, hasLength(1));
      expect(loaded.single.tripCode, 'lisbon-trip');
      expect(loaded.single.contributor, 'Maya');
      expect(loaded.single.type, MemoryType.photo);
      expect(loaded.single.bytes, Uint8List.fromList(const [1, 2, 3]));
      expect(loaded.single.caption, 'the churro incident');
      expect(loaded.single.locationName, 'Marina Pier');
      expect(loaded.single.createdAt, DateTime(2026, 6, 12, 10));

      // Another trip's queue is independent.
      expect(await store.loadFor('other-trip'), isEmpty);

      // Removing clears the queue for that trip.
      await store.remove('lisbon-trip');
      expect(await store.loadFor('lisbon-trip'), isEmpty);
    });
  });
}
