import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/main.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/widgets/brutal_widgets.dart';
import 'package:road_song/screens/typewriter_screen.dart';
import 'package:road_song/screens/evidence_screen.dart';
import 'package:road_song/screens/banger_screen.dart';
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
  });

  group('Brutal Widgets Tests', () {
    testWidgets('BrutalCard builds and can be tapped', (WidgetTester tester) async {
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
      final gesture = await tester.startGesture(tester.getCenter(find.text('Button Content')));
      await tester.pump();
      
      // Release gesture
      await gesture.up();
      await tester.pump();
      
      expect(pressed, isTrue);
    });

    testWidgets('Other auxiliary widgets render correctly', (WidgetTester tester) async {
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
      await tester.tap(find.text('START A TRIP SONG'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Lisbon Trip');
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OPEN THE DIARY →'));
      await tester.pumpAndSettle();
    }

    Future<void> switchToDemoTrip(WidgetTester tester, String tripName) async {
      await tester.tap(find.byKey(const ValueKey('switch-trip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('trip-row-$tripName')));
      await tester.pumpAndSettle();
    }

    testWidgets('Diary feed, likes and banner navigation to Song', (WidgetTester tester) async {
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
      expect(find.text('3 memories collected — ready to turn them into your song?'), findsOneWidget);

      // Like toggling: mem-1 starts at 12 likes, not liked by me.
      Finder likeCount(String id) => find.byKey(ValueKey('like-count-$id'));
      expect(tester.widget<Text>(likeCount('mem-1')).data, '12');
      await tester.tap(find.byKey(const ValueKey('like-mem-1')));
      await tester.pump();
      expect(tester.widget<Text>(likeCount('mem-1')).data, '13');
      await tester.tap(find.byKey(const ValueKey('like-mem-1')));
      await tester.pump();
      expect(tester.widget<Text>(likeCount('mem-1')).data, '12');

      // Banner navigates to the Song tab (studio).
      await tester.tap(find.byKey(const ValueKey('song-banner')));
      await tester.pumpAndSettle();
      expect(find.text('THE STUDIO'), findsOneWidget);
    });

    testWidgets('Route tab renders stops, pins, callouts and odometer', (WidgetTester tester) async {
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
      expect(find.byKey(const ValueKey('route-pin-mem-road-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-pin-mem-road-2')), findsOneWidget);

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
  });

  group('Typewriter Screen Tests', () {
    testWidgets('Interaction and simulation of generation', (WidgetTester tester) async {
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

    testWidgets('Claude API Settings dialog cancel/save', (WidgetTester tester) async {
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
        find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'sk-ant-api03-...'),
        'my-claude-api-key',
      );
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('CLAUDE API SETTINGS'), findsNothing);
    });

    testWidgets('Claude API generation success flow', (WidgetTester tester) async {
      _MockHttpClient.mockStatusCode = 200;
      _MockHttpClient.mockResponseBody = '{"content": [{"text": "Generated lyric content by Claude API"}]}';
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
        find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'sk-ant-api03-...'),
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

    testWidgets('Claude API generation error and network exception flows', (WidgetTester tester) async {
      _MockHttpClient.mockStatusCode = 400;
      _MockHttpClient.mockResponseBody = '{"error": {"message": "Invalid API key provided"}}';
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
        find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'sk-ant-api03-...'),
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
    testWidgets('Map pin clicks and scroll behavior', (WidgetTester tester) async {
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
              MapPin(memoryId: 'mem-1', label: 'THE INCIDENT', left: 50, top: 50),
              MapPin(memoryId: 'mem-2', label: 'BAD IDEA #4', right: 80, bottom: 40),
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

  group('Banger Screen Tests', () {
    testWidgets('Vibe selection, recording flow and playback toggle', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: BangerScreen(
            onBack: () {},
            tripName: "Cabo Fail '23",
            lyrics: "Left my passport in the Uber\nNow I'm crying by the pool\nSunburn looking like a lobster\nDave is sleeping on the stool",
          ),
        ),
      );

      // Dropdown selection
      expect(find.text('POP-PUNK (2000S)'), findsOneWidget);
      
      // Tap record button
      await tester.tap(find.text('PRESS RECORD'));
      await tester.pump();
      
      // Should show generating/recording states
      expect(find.text('Cooking the beat...'), findsOneWidget);

      // Let generator transition after 3 seconds
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // Playback screen loaded
      expect(find.text('NOW PLAYING'), findsOneWidget);

      // Toggle Play/Pause
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ElevenLabs API Settings dialog cancel/save', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: BangerScreen(
            onBack: () {},
            tripName: "Cabo Fail '23",
            lyrics: "Some lyrics",
          ),
        ),
      );

      // Open settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('ELEVENLABS SETTINGS'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('ELEVENLABS SETTINGS'), findsNothing);

      // Open settings again
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Enter API key
      await tester.enterText(
        find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Enter ElevenLabs API key...'),
        'my-eleven-labs-api-key',
      );
      await tester.pump();

      // Select duration
      await tester.tap(find.text('20S'));
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('ELEVENLABS SETTINGS'), findsNothing);
    });

    testWidgets('ElevenLabs API generation success flow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _MockHttpClient.mockStatusCode = 200;
      _MockHttpClient.mockResponseBytes = [1, 2, 3, 4];
      _MockHttpClient.mockNetworkError = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BangerScreen(
            onBack: () {},
            tripName: "Cabo Fail '23",
            lyrics: "Some lyrics",
          ),
        ),
      );

      // Set API key
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Enter ElevenLabs API key...'),
        'fake-elevenlabs-key',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      // Tap Press Record
      await tester.tap(find.text('PRESS RECORD'));
      await tester.pump();

      // Wait for generation and process microtasks
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('NOW PLAYING'), findsOneWidget);
    });

    testWidgets('ElevenLabs API generation error and exception flows', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _MockHttpClient.mockStatusCode = 400;
      _MockHttpClient.mockResponseBody = '{"detail": {"status": "INVALID_PROMPT", "message": "Prompt too long"}}';
      _MockHttpClient.mockResponseBytes = null;
      _MockHttpClient.mockNetworkError = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BangerScreen(
            onBack: () {},
            tripName: "Cabo Fail '23",
            lyrics: "Some lyrics",
          ),
        ),
      );

      // Set API key
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Enter ElevenLabs API key...'),
        'fake-elevenlabs-key',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      // Generate
      await tester.tap(find.text('PRESS RECORD'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show GENERATION FAILED dialog
      expect(find.text('GENERATION FAILED'), findsOneWidget);
      await tester.tap(find.text('DISMISS'));
      await tester.pumpAndSettle();

      // Exception flow
      _MockHttpClient.mockNetworkError = true;

      // Generate again
      await tester.tap(find.text('PRESS RECORD'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('GENERATION FAILED'), findsOneWidget);
      await tester.tap(find.text('DISMISS'));
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

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final Uri? url = invocation.positionalArguments.firstWhere(
      (arg) => arg is Uri,
      orElse: () => null,
    ) as Uri?;
    if (mockNetworkError && url != null && (url.host == 'api.anthropic.com' || url.host == 'api.elevenlabs.io')) {
      return Future<HttpClientRequest>.error(const SocketException('Connection failed'));
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

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final Uri? url;
  _MockHttpClientResponse(this.url);

  static const List<int> _transparentImage = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
  ];

  bool get _isApiRequest => url != null && (url!.host == 'api.anthropic.com' || url!.host == 'api.elevenlabs.io');

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
      if (invocation.memberName == #compressionState) return HttpClientResponseCompressionState.notCompressed;
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
      final List<int> bytes = _MockHttpClient.mockResponseBytes ?? _MockHttpClient.mockResponseBody.codeUnits;
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
