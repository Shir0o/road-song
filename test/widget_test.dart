import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/main.dart';

void main() {
  setUpAll(() {
    // Provide a mock HTTP client that returns 200 with empty PNG bytes
    HttpOverrides.global = _MockHttpOverrides();
  });

  testWidgets('App smoke test - verifies Scrapbook loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RoadSongApp());

    // Onboarding starts on the Welcome screen.
    expect(find.text('Road\nSong'), findsOneWidget);

    // Start a trip song -> Create Trip.
    await tester.tap(find.text('START A TRIP SONG'));
    await tester.pumpAndSettle();
    expect(find.text('New trip'), findsOneWidget);

    // Enter a trip name and continue -> Invite Crew.
    await tester.enterText(find.byType(TextField).first, 'Lisbon Trip');
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Who was on the trip?'), findsOneWidget);

    // Open the diary -> Main Shell with Scrapbook.
    await tester.tap(find.text('OPEN THE DIARY →'));
    await tester.pumpAndSettle();

    // Verify that the title of the scrapbook screen is displayed.
    expect(find.text('YOUR MESSY TRIPS'), findsOneWidget);

    // Verify that the navigation icons are present (Scrapbook, Studio, Profile).
    expect(find.byIcon(Icons.book), findsOneWidget);
    expect(find.byIcon(Icons.play_circle), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl || invocation.memberName == #get) {
      return Future.value(_MockHttpClientRequest());
    }
    return null;
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

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  static const List<int> _transparentImage = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #statusCode) return 200;
    if (invocation.memberName == #contentLength) return _transparentImage.length;
    if (invocation.memberName == #headers) return _MockHttpHeaders();
    if (invocation.memberName == #compressionState) return HttpClientResponseCompressionState.notCompressed;
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
