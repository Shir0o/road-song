import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_song/main.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/screens/guest_portal_screen.dart';
import 'package:road_song/services/remote_trip_store.dart';
import 'package:road_song/services/trip_link_sharer.dart';

import 'fake_backend.dart';

/// Whole-app guest flow tests at the app seam: the real [RoadSongApp] with
/// the fake backend injected as the trip-store client. No real network in CI.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// 1x1 transparent PNG — a decodable photo fixture.
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

  /// Routes the platform channel's clipboard messages into [calls] and
  /// answers `Clipboard.getData` with the last copied text.
  List<MethodCall> mockClipboard(WidgetTester tester) {
    final List<MethodCall> calls = <MethodCall>[];
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  /// Stubs the share_plus method channel so the share sheet is a no-op.
  void mockShareChannel(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => 'dev.fluttercommunity.plus/share/unavailable',
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        null,
      ),
    );
  }

  Future<FakeBackend> pumpGuestPortal(
    WidgetTester tester, {
    required String tripCode,
    FakeBackend? backend,
    GuestMediaPickers? pickers,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeBackend fake = backend ?? FakeBackend();
    // Seed a trip whose code matches the route the test opens.
    final Trip trip = await fake.createTrip(TripDraft(name: 'Lisbon Trip'));
    if (backend == null) {
      // The fake generates 'lisbon-trip-1'; the test opens that code.
      tripCode = trip.code;
    }

    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/t/$tripCode';
    addTearDown(
      () => tester.binding.platformDispatcher.defaultRouteNameTestValue = '/',
    );

    await tester.pumpWidget(
      RoadSongApp(
        guestClient: fake,
        guestMediaPickers: pickers ?? const GuestMediaPickers(),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  group('Guest portal (app seam, fake backend)', () {
    testWidgets('opening the trip link reaches the guest portal with the '
        'trip name and what to do', (tester) async {
      final FakeBackend fake = await pumpGuestPortal(tester, tripCode: 'x');

      expect(find.text('LISBON TRIP'), findsOneWidget);
      expect(find.textContaining('You were on this trip'), findsOneWidget);
      expect(find.byKey(const ValueKey('guest-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('guest-submit')), findsOneWidget);
      expect(fake.trips, hasLength(1));
    });

    testWidgets('a guest adds a text memory from the portal', (tester) async {
      final FakeBackend fake = await pumpGuestPortal(tester, tripCode: 'x');
      final String code = fake.trips.single.code;

      await tester.enterText(find.byKey(const ValueKey('guest-name')), 'Priya');
      await tester.enterText(
        find.byKey(const ValueKey('guest-note')),
        'The wrong hill, Sintra. Never again.',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('guest-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guest-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('guest-success')), findsOneWidget);
      expect(find.textContaining('Added to the trip'), findsOneWidget);

      final List<TimelineMemory> memories = fake.memoriesFor(code);
      expect(memories, hasLength(1));
      expect(memories.single.text, 'The wrong hill, Sintra. Never again.');
      expect(memories.single.contributor, 'Priya');
      expect(memories.single.type, MemoryType.text);
    });

    testWidgets('a guest adds a photo with progress and it lands on the '
        'backend', (tester) async {
      final FakeBackend fake = await pumpGuestPortal(
        tester,
        tripCode: 'x',
        pickers: GuestMediaPickers(photo: () async => Uint8List.fromList(kPng)),
      );
      final String code = fake.trips.single.code;

      await tester.enterText(find.byKey(const ValueKey('guest-name')), 'Maya');
      await tester.tap(find.text('PHOTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHOOSE PHOTO'));
      await tester.pumpAndSettle();
      expect(find.text('Photo attached'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('guest-caption')),
        'the churro incident',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('guest-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guest-submit')));
      await tester.pump();
      // Progress is visible while the upload runs.
      expect(find.byKey(const ValueKey('guest-progress')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('guest-success')), findsOneWidget);
      final List<TimelineMemory> memories = fake.memoriesFor(code);
      expect(memories, hasLength(1));
      expect(memories.single.type, MemoryType.photo);
      expect(memories.single.caption, 'the churro incident');
      expect(memories.single.contributor, 'Maya');
    });

    testWidgets('a guest adds a short video clip', (tester) async {
      final FakeBackend fake = await pumpGuestPortal(
        tester,
        tripCode: 'x',
        pickers: GuestMediaPickers(
          video: () async => Uint8List.fromList(List.filled(4096, 7)),
        ),
      );
      final String code = fake.trips.single.code;

      await tester.enterText(find.byKey(const ValueKey('guest-name')), 'Tom');
      await tester.tap(find.text('VIDEO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHOOSE CLIP'));
      await tester.pumpAndSettle();
      expect(find.text('Clip attached'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('guest-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guest-submit')));
      await tester.pumpAndSettle();

      final List<TimelineMemory> memories = fake.memoriesFor(code);
      expect(memories, hasLength(1));
      expect(memories.single.type, MemoryType.video);
      expect(memories.single.contributor, 'Tom');
    });

    testWidgets('a dropped upload shows the retry affordance and retry '
        'succeeds', (tester) async {
      final FakeBackend fake = await pumpGuestPortal(
        tester,
        tripCode: 'x',
        pickers: GuestMediaPickers(photo: () async => Uint8List.fromList(kPng)),
      );
      final String code = fake.trips.single.code;

      await tester.enterText(find.byKey(const ValueKey('guest-name')), 'Maya');
      await tester.tap(find.text('PHOTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHOOSE PHOTO'));
      await tester.pumpAndSettle();

      // First attempt: the fake backend drops the connection mid-upload.
      fake.simulateNextUploadDrop = true;
      await tester.ensureVisible(find.byKey(const ValueKey('guest-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guest-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('guest-upload-error')), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);
      expect(fake.memoriesFor(code), isEmpty);

      // Retry succeeds and the memory lands.
      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guest-success')), findsOneWidget);
      expect(fake.memoriesFor(code), hasLength(1));
    });

    testWidgets('oversized guest media is rejected with a clear message', (
      tester,
    ) async {
      await pumpGuestPortal(
        tester,
        tripCode: 'x',
        pickers: GuestMediaPickers(
          photo: () async => Uint8List(kGuestMaxPhotoBytes + 1),
          video: () async => Uint8List(kGuestMaxVideoBytes + 1),
        ),
      );

      await tester.tap(find.text('PHOTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHOOSE PHOTO'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guest-media-error')), findsOneWidget);
      expect(find.textContaining('keep photos under 12.0 MB'), findsOneWidget);

      await tester.tap(find.text('VIDEO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHOOSE CLIP'));
      await tester.pumpAndSettle();
      expect(find.textContaining('keep clips under 64.0 MB'), findsOneWidget);
    });

    testWidgets('an unknown trip code shows the not-found state with retry', (
      tester,
    ) async {
      final FakeBackend fake = FakeBackend();
      await fake.createTrip(const TripDraft(name: 'Lisbon Trip'));

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/t/unknown-code';
      addTearDown(
        () => tester.binding.platformDispatcher.defaultRouteNameTestValue = '/',
      );

      await tester.pumpWidget(RoadSongApp(guestClient: fake));
      await tester.pumpAndSettle();

      expect(find.text('TRIP NOT FOUND'), findsOneWidget);
      expect(find.text('TRY AGAIN'), findsOneWidget);
    });
  });

  group('Creator share/copy of the trip link', () {
    testWidgets('the diary header shares and copies the trip link', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      mockClipboard(tester);
      mockShareChannel(tester);

      final store = TripStore();
      await store.addTrip(
        Trip(
          id: 'trip-share',
          name: 'Big Sur Highway',
          firstDay: 'OCT 1',
          lastDay: 'OCT 5',
          coverIndex: 1,
          crew: const [],
          sessionLink: 'roadsong.app/t/big-sur',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(RoadSongApp(tripStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();

      // The share action is available on the created trip's diary.
      expect(find.byKey(const ValueKey('share-trip')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share-trip')));
      await tester.pumpAndSettle();

      // The link was copied to the clipboard and a confirmation shows.
      expect(find.textContaining('Trip link copied'), findsOneWidget);
      final String? clipboardText = await Clipboard.getData(
        'text/plain',
      ).then((d) => d?.text);
      expect(clipboardText, 'roadsong.app/t/big-sur');
    });

    testWidgets('TripLinkSharer builds the code-shaped link from a session '
        'link', (tester) async {
      const TripLinkSharer sharer = TripLinkSharer();
      final Trip trip = Trip(
        id: 't',
        name: 'Trip',
        firstDay: '',
        lastDay: '',
        coverIndex: 0,
        crew: const [],
        sessionLink: 'roadsong.app/t/lisbon-trip',
        createdAt: DateTime.now(),
      );
      expect(sharer.linkFor(trip), 'roadsong.app/t/lisbon-trip');
    });
  });

  group('Guest memories appear in the creator diary without restart', () {
    testWidgets('a RemoteTripStore-backed app shows a guest memory after the '
        'next poll', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FakeBackend backend = FakeBackend();
      final Trip trip = await backend.createTrip(
        const TripDraft(name: 'Live Trip'),
      );
      final RemoteTripStore store = RemoteTripStore(
        client: backend,
        pollInterval: const Duration(milliseconds: 50),
      );
      await store.addTrip(trip);
      await store.init();

      await tester.pumpWidget(RoadSongApp(tripStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();
      expect(find.text('No memories yet.'), findsOneWidget);

      // A guest adds a memory on the backend (another device).
      await backend.createMemory(
        trip.code,
        TimelineMemory(
          id: 'guest-live',
          author: '@priya',
          contributor: 'Priya',
          time: '10:00 AM',
          text: 'Live from the web — the wrong hill.',
          type: MemoryType.text,
          createdAt: DateTime(2026, 6, 12, 10),
        ),
      );

      // The next poll merges it; the diary (ChangeNotifier-driven) updates
      // without an app restart.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Live from the web — the wrong hill.'), findsOneWidget);
      expect(find.text('Priya'), findsOneWidget);

      // Stop the poll timer before the test body ends (the framework checks
      // for pending timers before tearDowns run).
      store.dispose();
    });
  });
}
