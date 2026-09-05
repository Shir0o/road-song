import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/screens/diary_tab.dart';
import 'package:road_song/screens/route_tab.dart';

/// 1x1 transparent PNG — a valid image for photo attachment tests.
const List<int> kTransparentPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DiaryTab feed', () {
    const TimelineMemory textMemory = TimelineMemory(
      id: 'm1',
      time: '10:12',
      author: '@maya',
      text: 'Tom ordered a galão with total confidence.',
      day: 1,
      dayDate: 'JUN 12',
      locationName: 'Rua Garrett, Lisbon',
      likes: 4,
      likedByMe: false,
    );
    const TimelineMemory photoMemory = TimelineMemory(
      id: 'm2',
      time: '18:40',
      author: '@you',
      text: 'All five of us on tram 28.',
      day: 1,
      dayDate: 'JUN 12',
      likes: 3,
      likedByMe: true,
      rotationDegrees: -2,
      imageUrl: 'https://example.com/tram28.jpg',
      photoCaption: 'tram 28, somehow all of us',
    );
    const TimelineMemory dayTwoMemory = TimelineMemory(
      id: 'm3',
      time: '20:55',
      author: '@tom',
      text: 'Miradouro sunset. Priya cried.',
      day: 2,
      dayDate: 'JUN 13',
      likes: 5,
      likedByMe: false,
    );

    Future<List<TimelineMemory>> pumpDiary(
      WidgetTester tester, {
      List<TimelineMemory> memories = const [],
      required ValueChanged<TimelineMemory> onAddMemory,
      VoidCallback? onOpenSong,
      VoidCallback? onSwitchTrip,
    }) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryTab(
            tripName: 'Lisbon Trip',
            tripDateRange: 'JUN 12 – JUN 18',
            memories: memories,
            onAddMemory: onAddMemory,
            onOpenSong: onOpenSong ?? () {},
            onSwitchTrip: onSwitchTrip ?? () {},
            pickPhotoBytes: () async => Uint8List.fromList(kTransparentPng),
          ),
        ),
      );
      return memories;
    }

    testWidgets('groups memories by day and shows polaroid caption', (tester) async {
      await pumpDiary(
        tester,
        memories: const [textMemory, photoMemory, dayTwoMemory],
        onAddMemory: (_) {},
      );

      expect(find.text('LISBON TRIP'), findsOneWidget);
      expect(find.text('JUN 12 – JUN 18 · 1 stop'), findsOneWidget);
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);
      // Day header sub-line: place · date, uppercase.
      expect(find.text('RUA GARRETT, LISBON · JUN 12'), findsOneWidget);

      // Text memory body and pinned meta.
      expect(find.textContaining('galão'), findsOneWidget);
      expect(find.text('10:12 · ⚑ Rua Garrett, Lisbon'), findsOneWidget);

      // Photo memory renders polaroid caption + hd photo marker.
      expect(find.text('tram 28, somehow all of us'), findsOneWidget);
      expect(find.text('hd photo'), findsOneWidget);

      // Banner counts all memories.
      expect(
        find.text('3 memories collected — ready to turn them into your song?'),
        findsOneWidget,
      );
    });

    testWidgets('like pill toggles counts in both directions', (tester) async {
      await pumpDiary(
        tester,
        memories: const [textMemory, photoMemory],
        onAddMemory: (_) {},
      );

      // m1 not liked by me: 4 -> 5 -> 4.
      Finder count(String id) => find.byKey(ValueKey('like-count-$id'));
      expect(tester.widget<Text>(count('m1')).data, '4');
      await tester.tap(find.byKey(const ValueKey('like-m1')));
      await tester.pump();
      expect(tester.widget<Text>(count('m1')).data, '5');
      await tester.tap(find.byKey(const ValueKey('like-m1')));
      await tester.pump();
      expect(tester.widget<Text>(count('m1')).data, '4');

      // m2 already liked by me: 3 -> 2 -> 3.
      expect(tester.widget<Text>(count('m2')).data, '3');
      await tester.tap(find.byKey(const ValueKey('like-m2')));
      await tester.pump();
      expect(tester.widget<Text>(count('m2')).data, '2');
      await tester.tap(find.byKey(const ValueKey('like-m2')));
      await tester.pump();
      expect(tester.widget<Text>(count('m2')).data, '3');
    });

    testWidgets('composer submits a text memory with a pinned place', (tester) async {
      final List<TimelineMemory> added = [];
      await pumpDiary(
        tester,
        memories: const [textMemory],
        onAddMemory: added.add,
      );

      await tester.tap(find.byKey(const ValueKey('add-memory-fab')));
      await tester.pumpAndSettle();
      expect(find.text('Add a memory'), findsOneWidget);

      // Existing pinned place is offered as a quick-pin chip.
      expect(
        find.byKey(const ValueKey('place-chip-Rua Garrett, Lisbon')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextField).first,
        'Pastéis de nata count: 19. Not sorry.',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('place-chip-Rua Garrett, Lisbon')),
      );
      await tester.pump();
      await tester.tap(find.text('Paste it in the scrapbook'));
      await tester.pumpAndSettle();

      expect(added, hasLength(1));
      final TimelineMemory memory = added.single;
      expect(memory.text, 'Pastéis de nata count: 19. Not sorry.');
      expect(memory.locationName, 'Rua Garrett, Lisbon');
      expect(memory.author, '@you');
      expect(memory.dayDate, isNotNull);
      expect(memory.photoBytes, isNull);

      // The memory joins a fresh day group unless today is the fixture's day
      // (JUN 12), in which case the fold rule keeps it on Day 1.
      final DateTime now = DateTime.now();
      final List<String> months = const [
        'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT',
        'NOV', 'DEC',
      ];
      final String todayLabel = '${months[now.month - 1]} ${now.day}';
      final bool foldsIntoDay1 = textMemory.dayDate == todayLabel;
      expect(memory.day, foldsIntoDay1 ? 1 : 2);

      // Re-pump with the added memory: the feed shows both memories grouped.
      await pumpDiary(
        tester,
        memories: [textMemory, memory],
        onAddMemory: (_) {},
      );
      if (!foldsIntoDay1) {
        expect(find.text('Day 2'), findsOneWidget);
      }
      expect(find.text('Day 1'), findsOneWidget);
      expect(
        find.text('2 memories collected — ready to turn them into your song?'),
        findsOneWidget,
      );
    });

    testWidgets('composer attaches a photo and a freshly typed place', (tester) async {
      final List<TimelineMemory> added = [];
      await pumpDiary(
        tester,
        memories: const [],
        onAddMemory: added.add,
      );

      await tester.tap(find.byKey(const ValueKey('add-memory-fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'The wrong hill, Sintra.',
      );
      await tester.enterText(
        find.byType(TextField).last,
        'Sintra, the wrong hill',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('attach-photo')));
      await tester.pumpAndSettle();
      expect(find.text('Photo attached'), findsOneWidget);

      await tester.tap(find.text('Paste it in the scrapbook'));
      await tester.pumpAndSettle();

      expect(added, hasLength(1));
      final TimelineMemory memory = added.single;
      expect(memory.locationName, 'Sintra, the wrong hill');
      expect(memory.photoBytes, isNotNull);
      expect(memory.photoBytes!.length, greaterThan(0));
      expect(memory.day, 1);

      // Re-pump: the photo memory renders a polaroid image.
      await pumpDiary(
        tester,
        memories: [memory],
        onAddMemory: (_) {},
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('same-day submissions join one day group', (tester) async {
      final List<TimelineMemory> added = [];
      await pumpDiary(tester, onAddMemory: added.add);

      // First submission on an empty trip starts Day 1.
      await tester.tap(find.byKey(const ValueKey('add-memory-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'First note today');
      await tester.pump();
      await tester.tap(find.text('Paste it in the scrapbook'));
      await tester.pumpAndSettle();
      expect(added, hasLength(1));

      // Second submission lands on the same day instead of a duplicate one.
      await pumpDiary(tester, memories: [added.first], onAddMemory: added.add);
      await tester.tap(find.byKey(const ValueKey('add-memory-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Second note today');
      await tester.pump();
      await tester.tap(find.text('Paste it in the scrapbook'));
      await tester.pumpAndSettle();

      expect(added, hasLength(2));
      expect(added[1].day, added[0].day);

      await pumpDiary(tester, memories: added, onAddMemory: (_) {});
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Day 2'), findsNothing);
      expect(find.textContaining('Second note today'), findsOneWidget);
    });

    testWidgets('dismissing the composer adds nothing', (tester) async {
      bool added = false;
      await pumpDiary(tester, onAddMemory: (_) => added = true);

      await tester.tap(find.byKey(const ValueKey('add-memory-fab')));
      await tester.pumpAndSettle();
      expect(find.text('Add a memory'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Add a memory'), findsNothing);
      expect(added, isFalse);
    });

    testWidgets('empty diary offers add-memory CTA', (tester) async {
      await pumpDiary(tester, onAddMemory: (_) {});
      expect(find.text('No memories yet.'), findsOneWidget);
      await tester.tap(find.text('ADD A MEMORY'));
      await tester.pumpAndSettle();
      expect(find.text('Add a memory'), findsOneWidget);
    });

    testWidgets('banner and switch-trip invoke their callbacks', (tester) async {
      bool openedSong = false;
      bool openedPicker = false;
      await pumpDiary(
        tester,
        memories: const [textMemory],
        onAddMemory: (_) {},
        onOpenSong: () => openedSong = true,
        onSwitchTrip: () => openedPicker = true,
      );

      await tester.tap(find.byKey(const ValueKey('song-banner')));
      expect(openedSong, isTrue);

      await tester.tap(find.byKey(const ValueKey('switch-trip')));
      expect(openedPicker, isTrue);
    });
  });

  group('Route helpers', () {
    const TimelineMemory pinnedA = TimelineMemory(
      id: 'a',
      time: '09:00',
      author: '@you',
      text: 'First stop note that is long enough to need truncating in rows.',
      day: 1,
      locationName: 'Alfama, Lisbon',
      latitude: 38.712,
      longitude: -9.131,
    );
    const TimelineMemory loose = TimelineMemory(
      id: 'b',
      time: '10:00',
      author: '@maya',
      text: 'Not pinned anywhere.',
      day: 1,
    );
    const TimelineMemory pinnedC = TimelineMemory(
      id: 'c',
      time: '11:00',
      author: '@tom',
      text: 'Sintra',
      day: 2,
      locationName: 'Sintra',
      latitude: 38.794,
      longitude: -9.388,
    );
    const TimelineMemory repeatA = TimelineMemory(
      id: 'd',
      time: '12:00',
      author: '@maya',
      text: 'Back to Alfama later.',
      day: 3,
      locationName: 'Alfama, Lisbon',
    );

    test('buildRouteStops keeps distinct pinned places in first-appearance order', () {
      final stops = buildRouteStops(const [pinnedA, loose, pinnedC, repeatA]);
      expect(stops, hasLength(2));
      expect(stops[0].placeName, 'Alfama, Lisbon');
      expect(stops[0].id, 'a'); // first memory to pin Alfama
      expect(stops[1].placeName, 'Sintra');
      expect(stops[1].id, 'c');
    });

    test('routeKilometers sums great-circle distance and skips uncoordinated stops', () {
      const RouteStop singleCoord = RouteStop(
        id: 'solo',
        placeName: 'Solo',
        author: 'x',
        time: 't',
        text: '',
        day: 1,
        latitude: 38.712,
        longitude: -9.131,
      );
      expect(routeKilometers(const []), 0);
      expect(routeKilometers(const [singleCoord]), 0);
      // Stops without coordinates never contribute.
      expect(
        routeKilometers(buildRouteStops(const [pinnedA, loose, repeatA])),
        0,
      );

      const RouteStop la = RouteStop(
        id: 'la',
        placeName: 'LA',
        author: 'x',
        time: 't',
        text: '',
        day: 1,
        latitude: 34.0522,
        longitude: -118.2437,
      );
      const RouteStop nyc = RouteStop(
        id: 'nyc',
        placeName: 'NYC',
        author: 'x',
        time: 't',
        text: '',
        day: 2,
        latitude: 40.7128,
        longitude: -74.006,
      );
      const RouteStop noCoord = RouteStop(
        id: 'nowhere',
        placeName: 'Nowhere',
        author: 'x',
        time: 't',
        text: '',
        day: 3,
      );
      expect(routeKilometers(const [la, nyc]), closeTo(3936, 30));
      // A stop without coordinates in the middle is skipped, not fatal.
      expect(routeKilometers(const [la, noCoord, nyc]), closeTo(3936, 30));
    });

    test('routeStopOffsets centers a single stop and fits coordinated routes', () {
      expect(routeStopOffsets(const [], const Size(300, 300)), isEmpty);

      const RouteStop singleCoord = RouteStop(
        id: 'solo',
        placeName: 'Solo',
        author: 'x',
        time: 't',
        text: '',
        day: 1,
        latitude: 38.712,
        longitude: -9.131,
      );
      final single =
          routeStopOffsets(const [singleCoord], const Size(300, 300));
      expect(single.single, const Offset(150, 150));

      // All-coords: every offset lands inside the canvas.
      const RouteStop secondCoord = RouteStop(
        id: 'second',
        placeName: 'Second',
        author: 'x',
        time: 't',
        text: '',
        day: 2,
        latitude: 38.794,
        longitude: -9.388,
      );
      final fitted = routeStopOffsets(
        const [singleCoord, secondCoord],
        const Size(300, 300),
      );
      expect(fitted, hasLength(2));
      for (final Offset offset in fitted) {
        expect(offset.dx, greaterThanOrEqualTo(0));
        expect(offset.dx, lessThanOrEqualTo(300));
        expect(offset.dy, greaterThanOrEqualTo(0));
        expect(offset.dy, lessThanOrEqualTo(300));
      }
      expect(fitted[0], isNot(fitted[1]));
    });

    test('routeStopOffsets lays out orderless stops on a monotonic curve', () {
      const List<TimelineMemory> noCoords = [
        TimelineMemory(
          id: 'x1',
          time: 't',
          author: 'a',
          text: 'one',
          day: 1,
          locationName: 'One',
        ),
        TimelineMemory(
          id: 'x2',
          time: 't',
          author: 'a',
          text: 'two',
          day: 1,
          locationName: 'Two',
        ),
        TimelineMemory(
          id: 'x3',
          time: 't',
          author: 'a',
          text: 'three',
          day: 1,
          locationName: 'Three',
        ),
      ];
      final noCoordStops = buildRouteStops(noCoords);
      expect(noCoordStops, hasLength(3));

      final offsets = routeStopOffsets(noCoordStops, const Size(300, 300));
      expect(offsets[0].dx, lessThan(offsets[1].dx));
      expect(offsets[1].dx, lessThan(offsets[2].dx));
      for (final Offset offset in offsets) {
        expect(offset.dy, greaterThan(0));
        expect(offset.dy, lessThan(300));
      }
    });
  });

  group('RouteTab', () {
    const TimelineMemory pinnedA = TimelineMemory(
      id: 'a',
      time: '09:00',
      author: '@you',
      text: 'Tram 28, all five of us. We fit. Barely.',
      day: 1,
      dayDate: 'JUN 12',
      locationName: 'Alfama, Lisbon',
      latitude: 38.712,
      longitude: -9.131,
    );
    const TimelineMemory loose = TimelineMemory(
      id: 'b',
      time: '10:00',
      author: '@maya',
      text: 'Pastéis. Not sorry.',
      day: 1,
    );
    const TimelineMemory pinnedC = TimelineMemory(
      id: 'c',
      time: '11:00',
      author: '@tom',
      text: 'Hiked 40 minutes the wrong way up to the castle.',
      day: 2,
      dayDate: 'JUN 13',
      locationName: 'Sintra, the wrong hill',
      latitude: 38.794,
      longitude: -9.388,
    );

    Future<void> pumpRoute(
      WidgetTester tester, {
      List<TimelineMemory> memories = const [],
      VoidCallback? onOpenDiary,
    }) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: RouteTab(
            tripName: 'Lisbon Trip',
            memories: memories,
            onOpenDiary: onOpenDiary ?? () {},
          ),
        ),
      );
    }

    testWidgets('renders pinned stops with odometer and pin callouts', (tester) async {
      await pumpRoute(
        tester,
        memories: const [pinnedA, loose, pinnedC],
      );

      expect(find.text('The route'), findsOneWidget);
      expect(find.text('2 stops · 24 km'), findsOneWidget);
      // Unpinned memory never becomes a pin or a row.
      expect(find.byKey(const ValueKey('route-pin-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-pin-c')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-pin-b')), findsNothing);
      expect(find.byKey(const ValueKey('stop-row-b')), findsNothing);
      expect(find.text('Alfama, Lisbon'), findsOneWidget);
      expect(find.text('Sintra, the wrong hill'), findsOneWidget);

      // Tap a pin: callout shows that stop's memory.
      await tester.tap(find.byKey(const ValueKey('route-pin-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-callout')), findsOneWidget);
      Finder inCallout(String text) => find.descendant(
            of: find.byKey(const ValueKey('pin-callout')),
            matching: find.textContaining(text),
          );
      expect(inCallout('Tram 28'), findsOneWidget);

      // Tap the other stop row: callout follows it.
      await tester.tap(find.byKey(const ValueKey('stop-row-c')));
      await tester.pumpAndSettle();
      expect(inCallout('wrong way up to the castle'), findsOneWidget);
      expect(inCallout('Tram 28'), findsNothing);

      // Tapping the selected stop row again dismisses the callout.
      await tester.tap(find.byKey(const ValueKey('stop-row-c')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-callout')), findsNothing);
    });

    testWidgets('empty route directs to adding a pinned memory', (tester) async {
      bool wentToDiary = false;
      await pumpRoute(
        tester,
        memories: const [loose],
        onOpenDiary: () => wentToDiary = true,
      );

      expect(find.textContaining('No pinned places yet'), findsOneWidget);
      expect(find.text('0 stops'), findsOneWidget);
      await tester.tap(find.text('ADD A MEMORY'));
      expect(wentToDiary, isTrue);
    });

    testWidgets('route with zero memories explains the route needs memories', (tester) async {
      await pumpRoute(tester);
      expect(find.textContaining('No memories yet'), findsOneWidget);
    });
  });
}
