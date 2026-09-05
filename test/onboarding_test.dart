import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_song/main.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/screens/welcome_screen.dart';
import 'package:road_song/screens/create_trip_screen.dart';
import 'package:road_song/screens/invite_crew_screen.dart';
import 'package:road_song/services/session_ingestion_service.dart';
import 'package:road_song/widgets/qr_code_view.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    HttpOverrides.global = _MockHttpOverrides();
  });

  group('WelcomeScreen', () {
    testWidgets('renders editorial copy and invokes onStart', (tester) async {
      bool started = false;
      await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(onStart: () => started = true)),
      );

      expect(find.text('Road\nSong'), findsOneWidget);
      expect(find.text('a scrapbook that sings ♪'), findsOneWidget);
      expect(find.text('START A TRIP SONG'), findsOneWidget);

      await tester.tap(find.text('START A TRIP SONG'));
      expect(started, isTrue);
    });
  });

  group('CreateTripScreen', () {
    testWidgets('collects trip name, dates and cover swatch', (tester) async {
      TripDraft? result;
      bool backed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CreateTripScreen(
            onBack: () => backed = true,
            onContinue: (draft) => result = draft,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Lisbon → Porto');
      await tester.enterText(find.byType(TextField).at(1), 'Jun 12');
      await tester.enterText(find.byType(TextField).at(2), 'Jun 18');
      await tester.pump();

      // Pick the second cover swatch.
      await tester.tap(find.byKey(const ValueKey('cover-1')));
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.name, 'Lisbon → Porto');
      expect(result!.firstDay, 'Jun 12');
      expect(result!.lastDay, 'Jun 18');
      expect(result!.coverIndex, 1);
      expect(backed, isFalse);
    });

    testWidgets('back button invokes onBack', (tester) async {
      bool backed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: CreateTripScreen(
            onBack: () => backed = true,
            onContinue: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('← Back'));
      expect(backed, isTrue);
    });
  });

  group('InviteCrewScreen', () {
    testWidgets('toggles friends and copies session link', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      TripDraft? resultDraft;
      List<CrewMember>? resultCrew;

      await tester.pumpWidget(
        MaterialApp(
          home: InviteCrewScreen(
            onBack: () {},
            draft: const TripDraft(name: 'Lisbon Trip'),
            onOpenDiary: (draft, crew) {
              resultDraft = draft;
              resultCrew = crew;
            },
          ),
        ),
      );

      expect(find.text('Who was on the trip?'), findsOneWidget);
      expect(find.text('roadsong.app/t/lisbon-trip'), findsOneWidget);
      expect(find.text('SCAN TO JOIN'), findsOneWidget);

      // Toggle Sam (initially not invited).
      await tester.tap(find.text('Sam Okafor'));
      await tester.pump();

      // Copy link updates the label.
      await tester.ensureVisible(find.text('Copy'));
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(find.text('Copied ✓'), findsOneWidget);

      await tester.ensureVisible(find.text('OPEN THE DIARY →'));
      await tester.tap(find.text('OPEN THE DIARY →'));
      await tester.pump();

      expect(resultDraft, isNotNull);
      expect(resultDraft!.name, 'Lisbon Trip');
      expect(resultCrew, isNotNull);
      expect(resultCrew!.firstWhere((m) => m.id == 'sam').invited, isTrue);
    });

    testWidgets('guest drop sheet uses ingestion service', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: InviteCrewScreen(
            onBack: () {},
            draft: const TripDraft(name: 'Lisbon Trip'),
            onOpenDiary: (_, __) {},
          ),
        ),
      );

      await tester.ensureVisible(find.text('DROP A MEMORY'));
      await tester.tap(find.text('DROP A MEMORY'));
      await tester.pumpAndSettle();
      expect(find.text('DROP A MEMORY'), findsNWidgets(2)); // button + sheet title

      await tester.enterText(
        find.byType(TextField).last,
        'Best churro ever',
      );
      await tester.pump();
      await tester.tap(find.text('DROP'));
      await tester.pump();

      expect(find.textContaining('dropped: Best churro ever'), findsOneWidget);
    });
  });

  group('Small screen layout', () {
    testWidgets('onboarding screens fit without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 520);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(onStart: () {})),
      );
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateTripScreen(onBack: () {}, onContinue: (_) {}),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          home: InviteCrewScreen(
            onBack: () {},
            draft: const TripDraft(name: 'x'),
            onOpenDiary: (_, __) {},
          ),
        ),
      );
      await tester.pump();
    });
  });

  group('OnboardingFlow', () {
    testWidgets('walks through welcome → create → invite → main shell', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const RoadSongApp());

      expect(find.text('Road\nSong'), findsOneWidget);

      await tester.tap(find.text('START A TRIP SONG'));
      await tester.pumpAndSettle();
      expect(find.text('New trip'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Cabo Revenge');
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('Who was on the trip?'), findsOneWidget);

      await tester.tap(find.text('OPEN THE DIARY →'));
      await tester.pumpAndSettle();
      // The hub opens on the created trip's (empty) diary.
      expect(find.text('CABO REVENGE'), findsOneWidget);
      expect(find.text('No memories yet.'), findsOneWidget);

      // The created trip is wired into the hub's trip switcher.
      await tester.tap(find.byKey(const ValueKey('switch-trip')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('trip-row-Cabo Revenge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey("trip-row-Cabo Fail '23")),
        findsOneWidget,
      );
    });
  });

  group('SessionIngestionService', () {
    const service = SessionIngestionService();

    test('slugify and buildSessionLink', () {
      expect(service.slugify('Lisbon → Porto'), 'lisbon-porto');
      expect(service.slugify('   '), 'trip');
      expect(
        service.buildSessionLink('Lisbon → Porto'),
        'roadsong.app/t/lisbon-porto',
      );
    });

    test('createTextDrop preserves text and timestamp', () {
      final timestamp = DateTime(2026, 6, 12, 9, 30);
      final drop = service.createTextDrop(
        author: '@maya',
        text: 'Best churro ever',
        timestamp: timestamp,
        location: 'Lisbon',
      );

      expect(drop.isText, isTrue);
      expect(drop.author, '@maya');
      expect(drop.content, 'Best churro ever');
      expect(drop.capturedAt, timestamp);
      expect(drop.location, 'Lisbon');
    });

    test('parseMediaDrop extracts EXIF DateTimeOriginal from JPEG', () {
      final bytes = _buildJpegWithExif('2026:06:12 09:30:00');
      final drop = service.parseMediaDrop(
        bytes: bytes,
        author: '@tom',
        filePath: '/tmp/photo.jpg',
        type: GuestDropType.photo,
        fallbackTimestamp: DateTime(2020, 1, 1),
      );

      expect(drop.isPhoto, isTrue);
      expect(drop.capturedAt, DateTime(2026, 6, 12, 9, 30));
    });

    test('parseMediaDrop falls back for video and non-EXIF bytes', () {
      final fallback = DateTime(2026, 7, 4, 18, 0);
      final videoDrop = service.parseMediaDrop(
        bytes: [1, 2, 3, 4],
        author: '@priya',
        filePath: '/tmp/clip.mp4',
        type: GuestDropType.video,
        fallbackTimestamp: fallback,
      );
      expect(videoDrop.isVideo, isTrue);
      expect(videoDrop.capturedAt, fallback);

      // Non-EXIF JPEG bytes should fall back too.
      final photoDrop = service.parseMediaDrop(
        bytes: [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x04, 0x4A, 0x46, 0x49, 0x46],
        author: '@maya',
        filePath: '/tmp/plain.jpg',
        type: GuestDropType.photo,
        fallbackTimestamp: fallback,
      );
      expect(photoDrop.capturedAt, fallback);
    });

    test('extractExifDateTime returns null for invalid input', () {
      expect(service.extractExifDateTime([]), isNull);
      expect(service.extractExifDateTime([0x00, 0x01, 0x02]), isNull);
    });
  });

  group('TripStore', () {
    test('stores created trips', () {
      final store = TripStore();
      expect(store.trips, isEmpty);

      store.addTrip(
        Trip(
          id: 'trip-1',
          name: 'Lisbon Trip',
          firstDay: 'Jun 12',
          lastDay: 'Jun 18',
          coverIndex: 1,
          crew: [],
          sessionLink: 'roadsong.app/t/lisbon-trip',
          createdAt: DateTime(2026, 6, 12),
        ),
      );

      expect(store.trips, hasLength(1));
      expect(store.trips.first.name, 'Lisbon Trip');
    });
  });

  group('QrCodeView', () {
    testWidgets('renders a real QR code from data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QrCodeView(data: 'roadsong.app/t/lisbon-trip')),
        ),
      );
      expect(find.byType(QrCodeView), findsOneWidget);
    });
  });
}

/// Builds a minimal JPEG with an EXIF DateTimeOriginal tag.
List<int> _buildJpegWithExif(String dateString) {
  final dateBytes = [
    ...dateString.codeUnits,
    0x00, // null terminator
  ];

  // TIFF header (little-endian), IFD0 right after header.
  const tiffHeader = [0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00];

  // IFD0 with one entry: DateTimeOriginal (0x9003), type 2, count 20.
  final dateOffset = tiffHeader.length + 2 + 12 + 4;
  final ifd0 = [
    0x01, 0x00, // entry count = 1
    0x03, 0x90, // tag 0x9003
    0x02, 0x00, // type ASCII
    0x14, 0x00, 0x00, 0x00, // count 20
    dateOffset & 0xFF, (dateOffset >> 8) & 0xFF, 0x00, 0x00, // value offset
    0x00, 0x00, 0x00, 0x00, // next IFD offset
  ];

  final payload = <int>[
    // "Exif\0\0"
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
    ...tiffHeader,
    ...ifd0,
    ...dateBytes,
  ];

  // JPEG segment length includes the two length bytes themselves.
  final length = payload.length + 2;
  return [
    0xFF, 0xD8, // SOI
    0xFF, 0xE1, // APP1
    (length >> 8) & 0xFF,
    length & 0xFF,
    ...payload,
  ];
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return Future.value(_MockHttpClientRequest());
  }
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #close) {
      return Future.value(_MockHttpClientResponse());
    }
    if (invocation.memberName == #headers) {
      return _MockHttpHeaders();
    }
    return null;
  }
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
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

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #statusCode) return 200;
    if (invocation.memberName == #contentLength)
      return _transparentImage.length;
    if (invocation.memberName == #headers) return _MockHttpHeaders();
    if (invocation.memberName == #compressionState)
      return HttpClientResponseCompressionState.notCompressed;
    return null;
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
