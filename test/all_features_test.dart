import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/main.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/screens/add_memory_sheet.dart';
import 'package:road_song/widgets/brutal_widgets.dart';
import 'package:road_song/screens/typewriter_screen.dart';
import 'package:road_song/screens/evidence_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    // Provide a mock HTTP client that returns 200 with empty PNG bytes
    HttpOverrides.global = _MockHttpOverrides();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _MockHttpClient.mockStatusCode = 200;
    _MockHttpClient.mockResponseBody = '';
    _MockHttpClient.mockResponseBytes = null;
    _MockHttpClient.mockNetworkError = false;
    _MockHttpClient.requestCount = 0;
  });

  group('Brutal Widgets Tests', () {
    testWidgets('BrutalCard builds and can be tapped', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrutalCard(
              color: Colors.red,
              rotationDegrees: 5.0,
              hasTape: true,
              onTap: () {
                tapped = true;
              },
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      expect(tapped, isTrue);
    });

    testWidgets('BrutalButton interactive states', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrutalButton(
              onPressed: () {
                pressed = true;
              },
              child: const Text('Button Content'),
            ),
          ),
        ),
      );

      expect(find.text('Button Content'), findsOneWidget);

      // Tap down/up sequences
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Button Content')),
      );
      await tester.pump();

      // Release gesture
      await gesture.up();
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('Other auxiliary widgets render correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DymoLabel(text: 'Dymo'),
                TapeOverlay(),
                GrainOverlay(child: Text('Child')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('DYMO'), findsOneWidget);
      expect(find.text('Child'), findsOneWidget);
    });
  });

  group('App Shell & Navigation Tests', () {
    Future<void> openCreatedTripDiary(WidgetTester tester) async {
      await tester.tap(find.text('Start a trip song'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Lisbon Trip');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open the diary →'));
      await tester.pumpAndSettle();
    }

    Future<void> switchToDemoTrip(WidgetTester tester, String tripName) async {
      await tester.tap(find.byKey(const ValueKey('switch-trip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('trip-row-$tripName')));
      await tester.pumpAndSettle();
    }

    testWidgets('Diary feed, likes and banner navigation to Song', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const RoadSongApp());

      // Land on the created (empty) trip diary.
      await openCreatedTripDiary(tester);
      expect(find.text('No memories yet.'), findsOneWidget);

      // Switch to the canned demo trip to browse a populated diary.
      await switchToDemoTrip(tester, "Cabo Fail '23");
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.text('the churro incident'), findsOneWidget);
      expect(
        find.text('3 memories collected — ready to turn them into your song?'),
        findsOneWidget,
      );

      // Like toggling: mem-1 starts at 12 likes, not liked by me.
      Finder likeCount(String id) => find.byKey(ValueKey('like-count-$id'));
      expect(tester.widget<Text>(likeCount('mem-1')).data, '12');
      await tester.tap(find.byKey(const ValueKey('like-mem-1')));
      await tester.pump();
      expect(tester.widget<Text>(likeCount('mem-1')).data, '13');
      await tester.tap(find.byKey(const ValueKey('like-mem-1')));
      await tester.pump();
      expect(tester.widget<Text>(likeCount('mem-1')).data, '12');

      // Banner navigates to the Song tab (lyricist start stage).
      await tester.tap(find.byKey(const ValueKey('song-banner')));
      await tester.pumpAndSettle();
      expect(find.text('Write our song'), findsOneWidget);
    });

    testWidgets('Song tab drafts lyrics from the demo trip memories', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const RoadSongApp());
      await openCreatedTripDiary(tester);
      await switchToDemoTrip(tester, "Cabo Fail '23");

      // Write our song → reading pass → lyrics drafted from the memories.
      await tester.tap(find.byKey(const ValueKey('song-banner')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Write our song'));
      await tester.pump();
      expect(find.text('READING 3 MEMORIES'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 3400));
      await tester.pump();
      expect(find.text('Every Wrong Turn'), findsOneWidget);
      expect(find.textContaining('Alex'), findsWidgets);

      // Lyrics reference the trip's own people and moments.
      expect(find.textContaining('seagull'), findsWidgets);

      // Chat refinement re-rolls the targeted section.
      await tester.enterText(
        find.byKey(const ValueKey('chat-input')),
        'make the chorus funnier',
      );
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        find.textContaining('Done — I punched up the chorus'),
        findsOneWidget,
      );
    });

    testWidgets('Route tab renders stops, pins, callouts and odometer', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const RoadSongApp());
      await openCreatedTripDiary(tester);
      await switchToDemoTrip(tester, "Roadtrip '22");

      // Route tab shows both pinned stops with the distance odometer.
      await tester.tap(find.byIcon(Icons.flag));
      await tester.pumpAndSettle();
      expect(find.text('The route'), findsOneWidget);
      expect(find.text('2 stops · 291 km'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('route-pin-mem-road-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('route-pin-mem-road-2')),
        findsOneWidget,
      );

      // Tapping a pin opens its callout with the memory text.
      await tester.tap(find.byKey(const ValueKey('route-pin-mem-road-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-callout')), findsOneWidget);
      expect(find.textContaining('Death Valley'), findsWidgets);

      // Tapping the other stop row moves the callout to that memory.
      await tester.tap(find.byKey(const ValueKey('stop-row-mem-road-2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('concrete dinosaurs'), findsWidgets);

      // Back to Diary tab via nav bar.
      await tester.tap(find.byIcon(Icons.edit_note));
      await tester.pumpAndSettle();
      expect(find.text('Day 1'), findsOneWidget);
    });

    testWidgets(
      'Whole-app zip flow navigation: Welcome -> New Trip -> Invite -> Diary -> Route -> Song stages',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const RoadSongApp());

        // 1. Welcome stage
        expect(find.text('Road\nSong'), findsOneWidget);
        expect(find.text('a scrapbook that sings ♪'), findsOneWidget);
        expect(find.text('Start a trip song'), findsOneWidget);
        expect(find.text('Resume trip'), findsNothing);

        // 2. New Trip stage
        await tester.tap(find.text('Start a trip song'));
        await tester.pumpAndSettle();
        expect(find.text('New trip'), findsOneWidget);

        await tester.enterText(
          find.byType(TextField).first,
          'Pacific Coast Highway',
        );
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 3. Invite Friends stage
        expect(find.text('Who was on the trip?'), findsOneWidget);
        expect(find.text('Open the diary →'), findsOneWidget);

        // 4. Diary Tab
        await tester.tap(find.text('Open the diary →'));
        await tester.pumpAndSettle();
        expect(find.text('PACIFIC COAST HIGHWAY'), findsOneWidget);
        expect(find.text('No memories yet.'), findsOneWidget);

        // Switch to Cabo demo trip to test populated tabs & song progression
        await switchToDemoTrip(tester, "Cabo Fail '23");
        expect(find.text('CABO FAIL \'23'), findsOneWidget);

        // 5. Route Tab
        await tester.tap(find.byIcon(Icons.flag));
        await tester.pumpAndSettle();
        expect(find.text('The route'), findsOneWidget);

        // 6. Song Tab (Start stage)
        await tester.tap(find.byIcon(Icons.music_note));
        await tester.pumpAndSettle();
        expect(find.text('Turn your trip\ninto a song'), findsOneWidget);
        expect(find.text('Write our song'), findsOneWidget);

        // 7. Song Reading stage -> Lyrics stage
        await tester.tap(find.text('Write our song'));
        await tester.pump();
        expect(find.text('READING 3 MEMORIES'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 3400));
        await tester.pump();
        expect(find.text('Every Wrong Turn'), findsOneWidget);

        // 8. Choose Sound stage
        await tester.ensureVisible(find.byKey(const ValueKey('choose-sound')));
        await tester.tap(find.byKey(const ValueKey('choose-sound')));
        await tester.pumpAndSettle();
        expect(find.text('How should it sound?'), findsOneWidget);

        // Pick vibe (pop punk)
        await tester.tap(find.byKey(const ValueKey('style-card-pop-punk')));
        await tester.pump();

        // 9. Making Song synthesis stage
        await tester.tap(find.byKey(const ValueKey('make-song')));
        await tester.pump();
        expect(find.text('Tuning the guitars…'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 3400));
        await tester.pumpAndSettle();

        // 10. Song Ready stage with Play and Share
        expect(find.text('Your song is ready!'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('play-highlight-reel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('share-memorial-card')),
          findsOneWidget,
        );

        // 11. Play Highlight Reel stage
        await tester.tap(find.byKey(const ValueKey('play-highlight-reel')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('reel-play-pause-button')),
          findsOneWidget,
        );

        // Back from player to ready
        await tester.tap(find.byKey(const ValueKey('reel-close-button')));
        await tester.pumpAndSettle();
        expect(find.text('Your song is ready!'), findsOneWidget);

        // 12. Share Memorial stage
        await tester.tap(find.byKey(const ValueKey('share-memorial-card')));
        await tester.pumpAndSettle();
        expect(find.text('SHARE MEMORIAL'), findsOneWidget);
        expect(find.text('KEEPSAKE'), findsOneWidget);

        // Back to ready
        await tester.tap(find.byKey(const ValueKey('memorial-back-button')));
        await tester.pumpAndSettle();
        expect(find.text('Your song is ready!'), findsOneWidget);
      },
    );

    testWidgets(
      'Whole-app resume flow: Welcome boots with Resume trip and navigates straight to trip hub',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final store = TripStore();
        store.addTrip(
          Trip(
            id: 'trip-resumed',
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

        expect(find.text('Road\nSong'), findsOneWidget);
        expect(find.text('Start a trip song'), findsOneWidget);
        expect(find.text('Resume trip'), findsOneWidget);

        await tester.ensureVisible(find.text('Resume trip'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Resume trip'));
        await tester.pumpAndSettle();

        expect(find.text('BIG SUR HIGHWAY'), findsOneWidget);
        expect(find.text('No memories yet.'), findsOneWidget);
      },
    );

    testWidgets(
      'Whole-app persistence flow: Create trip with manual participants survives restart and resumes with participants listed',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});

        // 1. Initial Launch
        final store1 = TripStore.persistent();
        await store1.init();

        await tester.pumpWidget(RoadSongApp(tripStore: store1));
        await tester.pumpAndSettle();

        // 2. Start trip
        await tester.tap(find.text('Start a trip song'));
        await tester.pumpAndSettle();

        // 3. Enter trip details
        await tester.enterText(find.byType(TextField).at(0), 'Amalfi Drive');
        await tester.enterText(find.byType(TextField).at(1), 'JUN 1');
        await tester.enterText(find.byType(TextField).at(2), 'JUN 7');
        await tester.tap(find.byKey(const ValueKey('cover-2')));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 4. Invite screen: add participant by hand
        expect(find.text('Who was on the trip?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add-participant-field')),
          'Elena Rostova',
        );
        await tester.tap(find.byKey(const ValueKey('add-participant-button')));
        await tester.pump();
        expect(find.text('Elena Rostova'), findsOneWidget);

        // 5. Open diary -> lands on trip home
        await tester.ensureVisible(find.text('Open the diary →'));
        await tester.tap(find.text('Open the diary →'));
        await tester.pumpAndSettle();

        expect(find.text('AMALFI DRIVE'), findsOneWidget);
        expect(find.text('JUN 1 – JUN 7 · 0 stops'), findsOneWidget);

        // Verify participant is in the Song tab
        await tester.tap(find.byIcon(Icons.music_note));
        await tester.pumpAndSettle();
        expect(find.text('Write our song'), findsOneWidget);

        // 6. Simulate app restart with a new instance of persistent store reading the same prefs
        final store2 = TripStore.persistent();
        await store2.init();
        expect(store2.trips.length, 1);

        await tester.pumpWidget(
          RoadSongApp(key: const ValueKey('restart-app'), tripStore: store2),
        );
        await tester.pumpAndSettle();

        // Welcome screen shows Resume trip button for active trip
        expect(find.text('Resume trip'), findsOneWidget);
        await tester.ensureVisible(find.text('Resume trip'));
        await tester.tap(find.text('Resume trip'));
        await tester.pumpAndSettle();

        // Verify resumed into Amalfi Drive
        expect(find.text('AMALFI DRIVE'), findsOneWidget);

        // Check Song tab retains participants
        await tester.tap(find.byIcon(Icons.music_note));
        await tester.pumpAndSettle();
        expect(find.text('Write our song'), findsOneWidget);
      },
    );
  });

  group('Add Memory Flow Tests', () {
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

    final Trip lisbonTrip = Trip(
      id: 'trip-mem',
      name: 'Lisbon Trip',
      firstDay: 'JUN 12',
      lastDay: 'JUN 18',
      coverIndex: 1,
      crew: const [
        CrewMember(
          id: 'user-1',
          name: 'Maya',
          handle: '@maya',
          initial: 'M',
          color: Color(0xFF7D8663),
          invited: true,
        ),
      ],
      sessionLink: 'roadsong.app/t/lisbon-trip',
      createdAt: DateTime(2026, 6, 12),
    );

    MemoryMediaPickers fakePickers({
      Uint8List? gallery,
      Uint8List? camera,
      Uint8List? video,
    }) {
      return MemoryMediaPickers(
        photoFromGallery: () async => gallery,
        photoFromCamera: () async => camera,
        videoClip: () async => video,
      );
    }

    Future<InMemoryTripStore> pumpTripApp(
      WidgetTester tester, {
      MemoryMediaPickers? pickers,
      List<TimelineMemory> memories = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = InMemoryTripStore(
        trips: [lisbonTrip.copyWith(memories: memories)],
        activeTripId: lisbonTrip.id,
      );
      await tester.pumpWidget(
        RoadSongApp(tripStore: store, mediaPickers: pickers ?? fakePickers()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();
      return store;
    }

    /// Drives the Add Memory sheet: optional media type, then note/caption/
    /// place, then submit.
    Future<void> compose(
      WidgetTester tester, {
      String? type,
      String note = '',
      String? caption,
      String? place,
    }) async {
      await tester.tap(find.byKey(const ValueKey('add-memory-fab')));
      await tester.pumpAndSettle();
      if (type != null) {
        await tester.tap(find.byKey(ValueKey('memory-type-$type')));
        await tester.pumpAndSettle();
      }
      if (note.isNotEmpty) {
        await tester.enterText(find.byKey(const ValueKey('memory-note')), note);
      }
      if (caption != null) {
        await tester.enterText(
          find.byKey(const ValueKey('memory-caption')),
          caption,
        );
      }
      if (place != null) {
        await tester.enterText(
          find.byKey(const ValueKey('memory-place')),
          place,
        );
      }
      await tester.pump();
      await tester.tap(find.text('Paste it in the scrapbook'));
      await tester.pumpAndSettle();
    }

    testWidgets('photo memories from gallery and camera land in the trip', (
      WidgetTester tester,
    ) async {
      final store = await pumpTripApp(
        tester,
        pickers: fakePickers(
          gallery: Uint8List.fromList(kPng),
          camera: Uint8List.fromList(kPng),
        ),
      );
      expect(find.text('No memories yet.'), findsOneWidget);

      await compose(
        tester,
        type: 'gallery',
        note: 'The churro incident.',
        caption: 'churro oclock',
        place: 'Marina Pier',
      );

      final galleryMemory = store.memoriesFor(lisbonTrip.id).single;
      expect(galleryMemory.type, MemoryType.photo);
      expect(galleryMemory.photoBytes, Uint8List.fromList(kPng));
      expect(galleryMemory.author, '@you');
      expect(galleryMemory.contributor, 'You');
      expect(galleryMemory.caption, 'churro oclock');
      expect(galleryMemory.createdAt, isNotNull);
      expect(galleryMemory.locationName, 'Marina Pier');
      expect(galleryMemory.latitude, isNull);
      expect(galleryMemory.longitude, isNull);
      expect(find.textContaining('churro incident'), findsOneWidget);
      expect(find.text('churro oclock'), findsOneWidget);

      await compose(tester, type: 'camera', note: 'Camera moment');

      final memories = store.memoriesFor(lisbonTrip.id);
      expect(memories, hasLength(2));
      expect(memories.last.text, 'Camera moment');
      expect(memories.last.type, MemoryType.photo);
      expect(memories.last.photoBytes, isNotNull);
      expect(find.text('Camera moment'), findsOneWidget);
    });

    testWidgets('video clip and lore memories land in the trip', (
      WidgetTester tester,
    ) async {
      final videoBytes = Uint8List.fromList(List.filled(4096, 7));
      final store = await pumpTripApp(
        tester,
        pickers: fakePickers(
          gallery: Uint8List.fromList(kPng),
          video: videoBytes,
        ),
      );

      await compose(
        tester,
        type: 'video',
        note: 'Tram 28, all of us.',
        caption: 'the tram ride',
        place: 'Rua Garrett, Lisbon',
      );

      final videoMemory = store.memoriesFor(lisbonTrip.id).single;
      expect(videoMemory.type, MemoryType.video);
      expect(videoMemory.videoBytes, videoBytes);
      expect(videoMemory.locationName, 'Rua Garrett, Lisbon');
      expect(videoMemory.latitude, isNull);
      expect(find.byKey(ValueKey('clip-${videoMemory.id}')), findsOneWidget);
      expect(find.text('SHORT CLIP'), findsOneWidget);
      expect(find.text('the tram ride'), findsOneWidget);

      await compose(tester, type: 'text', note: 'Inside joke: the wrong hill.');

      final memories = store.memoriesFor(lisbonTrip.id);
      expect(memories, hasLength(2));
      expect(memories.last.type, MemoryType.text);
      expect(memories.last.hasPhoto, isFalse);
      expect(memories.last.hasVideo, isFalse);
      expect(find.text('Inside joke: the wrong hill.'), findsOneWidget);
    });

    testWidgets('the contributor can caption, rename and delete their memory', (
      WidgetTester tester,
    ) async {
      final store = await pumpTripApp(
        tester,
        memories: [
          TimelineMemory(
            id: 'mem-mine',
            author: '@you',
            contributor: 'You',
            time: '10:00 AM',
            text: 'First note of the trip.',
            caption: 'rough caption',
            createdAt: DateTime(2026, 6, 12, 10),
            day: 1,
            dayDate: 'JUN 12',
          ),
        ],
      );
      expect(find.text('rough caption'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('edit-mem-mine')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('edit-caption')),
        'the real caption',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-contributor')),
        'Maya',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final edited = store.memoriesFor(lisbonTrip.id).single;
      expect(edited.displayCaption, 'the real caption');
      expect(edited.displayContributor, 'Maya');
      expect(edited.text, 'First note of the trip.');
      expect(find.text('the real caption'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('delete-mem-mine')));
      await tester.pumpAndSettle();

      expect(store.memoriesFor(lisbonTrip.id), isEmpty);
      expect(find.text('No memories yet.'), findsOneWidget);
    });

    testWidgets('oversized media picks are rejected with a brutalist message', (
      WidgetTester tester,
    ) async {
      final store = await pumpTripApp(
        tester,
        pickers: fakePickers(
          gallery: Uint8List(kMaxPhotoUploadBytes + 1),
          video: Uint8List(kMaxVideoUploadBytes + 1),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('add-memory-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('memory-type-gallery')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('memory-upload-error')), findsOneWidget);
      expect(find.textContaining('keep photos under 12.0 MB'), findsOneWidget);

      // The oversized pick never attaches, so nothing is stored from it.
      await tester.tap(find.text('Paste it in the scrapbook'));
      await tester.pumpAndSettle();
      expect(find.text('Add a memory'), findsOneWidget);
      expect(store.memoriesFor(lisbonTrip.id), isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('memory-note')),
        'note without media',
      );
      await tester.pump();
      await tester.tap(find.text('Paste it in the scrapbook'));
      await tester.pumpAndSettle();
      expect(store.memoriesFor(lisbonTrip.id).single.type, MemoryType.text);

      // Clips have their own, larger limit.
      await tester.tap(find.byKey(const ValueKey('add-memory-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('memory-type-video')));
      await tester.pumpAndSettle();
      expect(find.textContaining('keep clips under 64.0 MB'), findsOneWidget);
      expect(find.text('Add a memory'), findsOneWidget);
    });

    testWidgets('memories added in-app survive a full restart', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      final store1 = TripStore.persistent();
      await store1.init();
      await store1.addTrip(lisbonTrip);

      await tester.pumpWidget(
        RoadSongApp(tripStore: store1, mediaPickers: fakePickers()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();

      await compose(tester, type: 'text', note: 'Survives the restart.');
      expect(find.text('Survives the restart.'), findsOneWidget);

      // Simulate a full restart reading the same preferences.
      final store2 = TripStore.persistent();
      await store2.init();
      expect(
        store2.memoriesFor(lisbonTrip.id).single.text,
        'Survives the restart.',
      );

      await tester.pumpWidget(
        RoadSongApp(
          key: const ValueKey('restart-mem'),
          tripStore: store2,
          mediaPickers: fakePickers(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Resume trip'));
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();

      expect(find.text('Survives the restart.'), findsOneWidget);
    });
  });

  group('Diary Feed & Reading View Tests', () {
    /// 1x1 transparent PNG — a decodable photo fixture.
    const List<int> kFeedPng = [
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

    final Trip feedTrip = Trip(
      id: 'trip-feed',
      name: 'Feed Trip',
      firstDay: 'JUN 12',
      lastDay: 'JUN 18',
      coverIndex: 1,
      crew: const [],
      sessionLink: 'roadsong.app/t/feed-trip',
      createdAt: DateTime(2026, 6, 12),
    );

    TimelineMemory feedMemory(
      String id, {
      required int day,
      required DateTime createdAt,
      required String text,
      String contributor = 'You',
      String caption = '',
    }) {
      return TimelineMemory(
        id: id,
        author: '@you',
        contributor: contributor,
        time: '10:00 AM',
        text: text,
        caption: caption,
        createdAt: createdAt,
        day: day,
        dayDate: 'JUN ${day + 11}',
      );
    }

    MemoryMediaPickers feedPickers() => MemoryMediaPickers(
      photoFromGallery: () async => Uint8List.fromList(kFeedPng),
      photoFromCamera: () async => Uint8List.fromList(kFeedPng),
      videoClip: () async => Uint8List.fromList(const [1, 2, 3]),
    );

    Future<InMemoryTripStore> pumpFeedApp(
      WidgetTester tester, {
      required List<TimelineMemory> memories,
    }) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = InMemoryTripStore(
        trips: [feedTrip.copyWith(memories: memories)],
        activeTripId: feedTrip.id,
      );
      await tester.pumpWidget(
        RoadSongApp(tripStore: store, mediaPickers: feedPickers()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('diary lists memories chronologically with day grouping', (
      tester,
    ) async {
      // Preset out of order: the day-2 memory was created before the day-1
      // ones, the day-1 pair is reversed, and one fixture carries no
      // createdAt at all (canned-fixture style) so it sorts by display time.
      await pumpFeedApp(
        tester,
        memories: [
          feedMemory(
            'm-late',
            day: 2,
            createdAt: DateTime(2026, 6, 13, 9),
            text: 'Day two note.',
          ),
          const TimelineMemory(
            id: 'm-fixture',
            author: '@tom',
            contributor: 'Tom',
            time: '09:00 AM',
            text: 'Canned fixture note.',
            day: 1,
            dayDate: 'JUN 12',
          ),
          feedMemory(
            'm-early',
            day: 1,
            createdAt: DateTime(2026, 6, 12, 8),
            text: 'Day one note.',
            contributor: 'Maya',
          ),
          feedMemory(
            'm-mid',
            day: 1,
            createdAt: DateTime(2026, 6, 12, 12),
            text: 'Day one later note.',
            caption: 'the tram ride',
          ),
        ],
      );

      // Day grouping from the memory day/dayDate fields.
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);

      // Chronological order on screen: earliest first, latest last. The
      // createdAt-less fixture sorts after every dated memory (dated entries
      // always precede undated ones), so it lands at the end of Day 1, before
      // the Day 2 memory.
      final double fixtureY = tester
          .getTopLeft(find.byKey(const ValueKey('memory-m-fixture')))
          .dy;
      final double earlyY = tester
          .getTopLeft(find.byKey(const ValueKey('memory-m-early')))
          .dy;
      final double midY = tester
          .getTopLeft(find.byKey(const ValueKey('memory-m-mid')))
          .dy;
      final double lateY = tester
          .getTopLeft(find.byKey(const ValueKey('memory-m-late')))
          .dy;
      expect(earlyY, lessThan(midY));
      expect(midY, lessThan(fixtureY));
      expect(fixtureY, lessThan(lateY));

      // Contributor and caption are visible per entry.
      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
      expect(find.text('the tram ride'), findsOneWidget);
    });

    testWidgets('empty trip shows the designed empty state with add-memory '
        'affordance', (tester) async {
      await pumpFeedApp(tester, memories: const []);

      expect(find.text('No memories yet.'), findsOneWidget);
      await tester.tap(find.text('ADD A MEMORY'));
      await tester.pumpAndSettle();
      expect(find.text('Add a memory'), findsOneWidget);
    });

    testWidgets('opening a memory shows the reader and back restores the '
        'scroll position', (tester) async {
      final List<TimelineMemory> memories = [
        for (int i = 0; i < 16; i++)
          feedMemory(
            'm-$i',
            day: (i ~/ 4) + 1,
            createdAt: DateTime(2026, 6, 12 + (i ~/ 4), 8 + i),
            text:
                'Note number $i — a memory body long enough to wrap across '
                'several lines so the feed grows tall enough to scroll.',
          ),
      ];
      await pumpFeedApp(tester, memories: memories);

      // Scroll deep into the feed so the top of the list leaves the viewport.
      final Finder diaryScrollable = find.descendant(
        of: find.byKey(const ValueKey('diary-feed')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('memory-m-12')),
        200,
        scrollable: diaryScrollable,
      );
      await tester.pumpAndSettle();

      final double offsetBefore = tester
          .widget<ListView>(find.byKey(const ValueKey('diary-feed')))
          .controller!
          .offset;
      expect(offsetBefore, greaterThan(0));

      // Open the memory: full-screen reader with the memory's own content.
      await tester.tap(find.byKey(const ValueKey('memory-m-12')));
      await tester.pumpAndSettle();
      expect(find.text('MEMORY'), findsOneWidget);
      expect(
        find.text(
          'Note number 12 — a memory body long enough to wrap '
          'across several lines so the feed grows tall enough to scroll.',
        ),
        findsOneWidget,
      );
      expect(find.text('You'), findsOneWidget);

      // Back returns to the same scroll position.
      await tester.tap(find.byKey(const ValueKey('reader-back')));
      await tester.pumpAndSettle();
      final double offsetAfter = tester
          .widget<ListView>(find.byKey(const ValueKey('diary-feed')))
          .controller!
          .offset;
      expect(offsetAfter, offsetBefore);
    });

    testWidgets('reader renders photo and video media full-screen', (
      tester,
    ) async {
      final photoMemory = feedMemory(
        'm-photo',
        day: 1,
        createdAt: DateTime(2026, 6, 12, 8),
        text: 'The churro incident.',
        caption: 'churro oclock',
      ).copyWith(photoBytes: Uint8List.fromList(kFeedPng));
      final videoMemory = feedMemory(
        'm-video',
        day: 1,
        createdAt: DateTime(2026, 6, 12, 12),
        text: 'Tram 28, all of us.',
        caption: 'the tram ride',
      ).copyWith(videoBytes: Uint8List.fromList(List.filled(4096, 7)));
      final networkPhoto = feedMemory(
        'm-net',
        day: 1,
        createdAt: DateTime(2026, 6, 12, 14),
        text: 'Remote photo memory.',
        caption: 'from the web',
      ).copyWith(imageUrl: 'https://example.com/remote.jpg');
      final textMemory = feedMemory(
        'm-text',
        day: 1,
        createdAt: DateTime(2026, 6, 12, 16),
        text: 'Lore only, no media.',
        caption: 'the inside joke',
      );
      await pumpFeedApp(
        tester,
        memories: [photoMemory, videoMemory, networkPhoto, textMemory],
      );

      // Photo memory: reader shows the polaroid with its caption.
      await tester.tap(find.byKey(const ValueKey('memory-m-photo')));
      await tester.pumpAndSettle();
      expect(find.text('MEMORY'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('churro oclock'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reader-back')));
      await tester.pumpAndSettle();

      // Video memory: reader shows the clip tile with its caption.
      await tester.tap(find.byKey(const ValueKey('memory-m-video')));
      await tester.pumpAndSettle();
      expect(find.text('SHORT CLIP'), findsOneWidget);
      expect(find.text('the tram ride'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reader-back')));
      await tester.pumpAndSettle();

      // Remote-photo memory: reader renders the network image.
      await tester.tap(find.byKey(const ValueKey('memory-m-net')));
      await tester.pumpAndSettle();
      expect(find.text('from the web'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reader-back')));
      await tester.pumpAndSettle();

      // Text memory: reader shows the lore body and its caption.
      await tester.tap(find.byKey(const ValueKey('memory-m-text')));
      await tester.pumpAndSettle();
      expect(find.text('Lore only, no media.'), findsOneWidget);
      expect(find.text('the inside joke'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reader-back')));
      await tester.pumpAndSettle();
      expect(find.text('MEMORY'), findsNothing);
    });
  });

  group('Route View Flow Tests', () {
    final Trip routeTrip = Trip(
      id: 'trip-route',
      name: 'Route Trip',
      firstDay: 'JUN 12',
      lastDay: 'JUN 18',
      coverIndex: 1,
      crew: const [],
      sessionLink: 'roadsong.app/t/route-trip',
      createdAt: DateTime(2026, 6, 12),
    );

    TimelineMemory routeMemory(
      String id, {
      required int day,
      required DateTime createdAt,
      required String text,
      required String place,
      double? latitude,
      double? longitude,
    }) {
      return TimelineMemory(
        id: id,
        author: '@you',
        contributor: 'You',
        time: '10:00 AM',
        text: text,
        createdAt: createdAt,
        day: day,
        dayDate: 'JUN ${day + 11}',
        locationName: place,
        latitude: latitude,
        longitude: longitude,
      );
    }

    Future<InMemoryTripStore> pumpRouteApp(
      WidgetTester tester, {
      required List<TimelineMemory> memories,
    }) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = InMemoryTripStore(
        trips: [routeTrip.copyWith(memories: memories)],
        activeTripId: routeTrip.id,
      );
      await tester.pumpWidget(
        RoadSongApp(tripStore: store, mediaPickers: MemoryMediaPickers()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('route renders pinned stops in chronological order from the '
        'store, unpinned memories never appear', (tester) async {
      // Contribution order is deliberately scrambled: the day-2 stop was
      // contributed first, the day-1 stop second, and an unpinned memory sits
      // between them. The route must follow chronological (createdAt) order.
      await pumpRouteApp(
        tester,
        memories: [
          routeMemory(
            'm-late',
            day: 2,
            createdAt: DateTime(2026, 6, 13, 9),
            text: 'The wrong hill, Sintra.',
            place: 'Sintra, the wrong hill',
            latitude: 38.794,
            longitude: -9.388,
          ),
          TimelineMemory(
            id: 'm-loose',
            author: '@maya',
            contributor: 'Maya',
            time: '10:00 AM',
            text: 'Not pinned anywhere.',
            createdAt: DateTime(2026, 6, 12, 10),
            day: 1,
            dayDate: 'JUN 12',
          ),
          routeMemory(
            'm-early',
            day: 1,
            createdAt: DateTime(2026, 6, 12, 8),
            text: 'Tram 28, all of us.',
            place: 'Alfama, Lisbon',
            latitude: 38.712,
            longitude: -9.131,
          ),
        ],
      );

      await tester.tap(find.byIcon(Icons.flag));
      await tester.pumpAndSettle();

      // Stop count and both pinned stops, in chronological order.
      expect(find.text('The route'), findsOneWidget);
      expect(find.text('2 stops · 24 km'), findsOneWidget);
      expect(find.byKey(const ValueKey('route-pin-m-early')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-pin-m-late')), findsOneWidget);

      // The unpinned memory never becomes a pin or a stop row.
      expect(find.byKey(const ValueKey('route-pin-m-loose')), findsNothing);
      expect(find.byKey(const ValueKey('stop-row-m-loose')), findsNothing);

      // Chronological order on screen: the day-1 stop leads, the day-2 stop
      // follows, even though the day-2 memory was contributed first.
      final double earlyY = tester
          .getTopLeft(find.byKey(const ValueKey('stop-row-m-early')))
          .dy;
      final double lateY = tester
          .getTopLeft(find.byKey(const ValueKey('stop-row-m-late')))
          .dy;
      expect(earlyY, lessThan(lateY));
      expect(find.text('Alfama, Lisbon'), findsOneWidget);
      expect(find.text('Sintra, the wrong hill'), findsOneWidget);

      // Diary/Route tab switching still works.
      await tester.tap(find.byIcon(Icons.edit_note));
      await tester.pumpAndSettle();
      expect(find.text('Day 1'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.flag));
      await tester.pumpAndSettle();
      expect(find.text('The route'), findsOneWidget);
    });

    testWidgets('empty route shows the designed empty state and makes no '
        'network calls', (tester) async {
      await pumpRouteApp(
        tester,
        memories: [
          TimelineMemory(
            id: 'm-loose',
            author: '@maya',
            contributor: 'Maya',
            time: '10:00 AM',
            text: 'Not pinned anywhere.',
            createdAt: DateTime(2026, 6, 12, 10),
            day: 1,
            dayDate: 'JUN 12',
          ),
        ],
      );

      await tester.tap(find.byIcon(Icons.flag));
      await tester.pumpAndSettle();

      // Empty state: brutalist hint that pinning a place adds a stop.
      expect(find.text('0 stops'), findsOneWidget);
      expect(
        find.textContaining('No pinned places yet'),
        findsOneWidget,
      );
      expect(find.textContaining('Pin a place to a memory'), findsOneWidget);

      // The route surface is fully offline: no HTTP requests at all.
      expect(_MockHttpClient.requestCount, 0);
    });
  });

  group('Typewriter Screen Tests', () {
    testWidgets('Interaction and simulation of generation', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TypewriterScreen(
            onBack: () {},
            onProduceTrack: () {},
            tripName: "Cabo Fail '23",
            initialLyrics: "Oh Cabo...",
            memories: const [],
            onLyricsUpdated: (_) {},
          ),
        ),
      );

      // Verify toolbar buttons
      expect(find.text('[B]'), findsOneWidget);
      expect(find.text('[I]'), findsOneWidget);

      // Tap generate verse
      await tester.tap(find.text('GENERATE VERSE'));
      await tester.pump();
      expect(find.text('GENERATING...'), findsOneWidget);

      // Wait for timer simulation
      await tester.pump(const Duration(milliseconds: 600));
      // Typewriter timer keeps periodic updates
      await tester.pump(const Duration(seconds: 10));

      // Verify generation completes
      expect(find.text('GENERATE VERSE'), findsOneWidget);
    });

    testWidgets('Claude API Settings dialog cancel/save', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TypewriterScreen(
            onBack: () {},
            onProduceTrack: () {},
            tripName: "Cabo Fail '23",
            initialLyrics: "Oh Cabo...",
            memories: const [],
            onLyricsUpdated: (_) {},
          ),
        ),
      );

      // Open settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('CLAUDE API SETTINGS'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('CLAUDE API SETTINGS'), findsNothing);

      // Open settings again
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Enter API key
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'sk-ant-api03-...',
        ),
        'my-claude-api-key',
      );
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('CLAUDE API SETTINGS'), findsNothing);
    });

    testWidgets('Claude API generation success flow', (
      WidgetTester tester,
    ) async {
      _MockHttpClient.mockStatusCode = 200;
      _MockHttpClient.mockResponseBody =
          '{"content": [{"text": "Generated lyric content by Claude API"}]}';
      _MockHttpClient.mockNetworkError = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TypewriterScreen(
            onBack: () {},
            onProduceTrack: () {},
            tripName: "Cabo Fail '23",
            initialLyrics: "Oh Cabo...",
            memories: const [],
            onLyricsUpdated: (_) {},
          ),
        ),
      );

      // Open settings and save API key
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'sk-ant-api03-...',
        ),
        'sk-ant-fake-key-123',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      // Tap generate verse
      await tester.tap(find.text('GENERATE VERSE'));
      await tester.pump();
      expect(find.text('GENERATING...'), findsOneWidget);

      // Wait for API call and animation timer
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Verify generation completes
      expect(find.text('GENERATE VERSE'), findsOneWidget);
    });

    testWidgets('Claude API generation error and network exception flows', (
      WidgetTester tester,
    ) async {
      _MockHttpClient.mockStatusCode = 400;
      _MockHttpClient.mockResponseBody =
          '{"error": {"message": "Invalid API key provided"}}';
      _MockHttpClient.mockNetworkError = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TypewriterScreen(
            onBack: () {},
            onProduceTrack: () {},
            tripName: "Cabo Fail '23",
            initialLyrics: "Oh Cabo...",
            memories: const [],
            onLyricsUpdated: (_) {},
          ),
        ),
      );

      // Set API key
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'sk-ant-api03-...',
        ),
        'sk-ant-bad-key',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      // Generate
      await tester.tap(find.text('GENERATE VERSE'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Network error exception
      _MockHttpClient.mockNetworkError = true;

      // Tap generate verse again
      await tester.tap(find.text('GENERATE VERSE'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  group('Evidence Screen Tests', () {
    testWidgets('Map pin clicks and scroll behavior', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceScreen(
            onBack: () {},
            tripName: "Cabo Fail '23",
            mapImageUrl: "",
            memories: const [
              TimelineMemory(
                id: 'mem-1',
                time: '11:42 PM',
                author: '@alex',
                text: 'Alex tried to fight a seagull...',
                icon: Icons.bolt,
                iconBg: Colors.yellow,
              ),
              TimelineMemory(
                id: 'mem-2',
                time: '02:15 AM',
                author: '@sarah',
                text: 'Ended up at...',
                icon: Icons.local_fire_department,
                iconBg: Colors.red,
              ),
            ],
            mapPins: const [
              MapPin(
                memoryId: 'mem-1',
                label: 'THE INCIDENT',
                left: 50,
                top: 50,
              ),
              MapPin(
                memoryId: 'mem-2',
                label: 'BAD IDEA #4',
                right: 80,
                bottom: 40,
              ),
            ],
            onAddMemory: (_) {},
          ),
        ),
      );

      // Click Add the Tea
      await tester.tap(find.text('ADD THE TEA'));
      await tester.pumpAndSettle();
      expect(find.text('ADD NEW EVIDENCE'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      // Click Map Pins
      await tester.tap(find.text('THE INCIDENT'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('BAD IDEA #4'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient implements HttpClient {
  static int mockStatusCode = 200;
  static String mockResponseBody = '';
  static List<int>? mockResponseBytes;
  static bool mockNetworkError = false;

  /// Total HTTP requests issued since the last reset — lets tests assert that
  /// a surface (e.g. the route view) makes no network calls at all.
  static int requestCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final Uri? url =
        invocation.positionalArguments.firstWhere(
              (arg) => arg is Uri,
              orElse: () => null,
            )
            as Uri?;
    requestCount++;
    if (mockNetworkError &&
        url != null &&
        (url.host == 'api.anthropic.com' || url.host == 'api.elevenlabs.io')) {
      return Future<HttpClientRequest>.error(
        const SocketException('Connection failed'),
      );
    }
    return Future.value(_MockHttpClientRequest(url));
  }
}

class _MockHttpClientRequest implements HttpClientRequest {
  final Uri? url;
  _MockHttpClientRequest(this.url);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      if (invocation.memberName == #headers) {
        return _MockHttpHeaders();
      }
      if (invocation.memberName == #encoding) {
        return utf8;
      }
      return null;
    }
    if (invocation.isSetter) {
      return null;
    }
    if (invocation.memberName == #close) {
      return Future.value(_MockHttpClientResponse(url));
    }
    return Future.value();
  }
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final Uri? url;
  _MockHttpClientResponse(this.url);

  static const List<int> _transparentImage = [
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

  bool get _isApiRequest =>
      url != null &&
      (url!.host == 'api.anthropic.com' || url!.host == 'api.elevenlabs.io');

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      if (invocation.memberName == #statusCode) {
        return _isApiRequest ? _MockHttpClient.mockStatusCode : 200;
      }
      if (invocation.memberName == #contentLength) {
        if (_isApiRequest) {
          if (_MockHttpClient.mockResponseBytes != null) {
            return _MockHttpClient.mockResponseBytes!.length;
          }
          return _MockHttpClient.mockResponseBody.codeUnits.length;
        }
        return _transparentImage.length;
      }
      if (invocation.memberName == #headers) return _MockHttpHeaders();
      if (invocation.memberName == #compressionState)
        return HttpClientResponseCompressionState.notCompressed;
      if (invocation.memberName == #isRedirect) return false;
      if (invocation.memberName == #persistentConnection) return false;
      if (invocation.memberName == #reasonPhrase) return 'OK';
      if (invocation.memberName == #redirects) return const <RedirectInfo>[];
      if (invocation.memberName == #cookies) return const <Cookie>[];
      return null;
    }
    if (invocation.isSetter) {
      return null;
    }
    return null;
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    List<int> responseBytes = _transparentImage;
    if (_isApiRequest) {
      final List<int> bytes =
          _MockHttpClient.mockResponseBytes ??
          _MockHttpClient.mockResponseBody.codeUnits;
      if (bytes.isNotEmpty) {
        responseBytes = bytes;
      }
    }
    return Stream<List<int>>.fromIterable([responseBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
