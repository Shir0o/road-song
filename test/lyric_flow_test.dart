import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_song/main.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seam A flow tests: pump the real app with a store-backed trip and drive
/// the lyric journey — write song, edit a line, rewrite a section, restart
/// with a fresh store instance — asserting the edits survive at the app seam.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const TimelineMemory kChurroMemory = TimelineMemory(
    id: 'm1',
    author: '@alex',
    time: '11:42 PM',
    text: 'Alex tried to fight a seagull for the last churro. The seagull won.',
    day: 1,
    locationName: 'Marina Pier',
  );

  const TimelineMemory kLaundryMemory = TimelineMemory(
    id: 'm2',
    author: '@sarah',
    time: '02:15 AM',
    text: 'Ended up at a 24hr laundromat playing poker with candy wrappers.',
    day: 1,
    locationName: 'The 24hr Laundromat',
  );

  const TimelineMemory kKaraokeMemory = TimelineMemory(
    id: 'm3',
    author: '@group',
    time: '04:00 AM',
    text: 'Karaoke meltdown. We owe the owner an apology.',
    day: 2,
    locationName: 'Karaoke Den',
  );

  const List<TimelineMemory> kCaboMemories = [
    kChurroMemory,
    kLaundryMemory,
    kKaraokeMemory,
  ];

  Trip tripFixture({List<TimelineMemory> memories = const []}) {
    return Trip(
      id: 'trip-flow',
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
        CrewMember(
          id: 'tom',
          name: 'Tom Okafor',
          handle: '@tom',
          initial: 'T',
          color: Color(0xFFB08A3E),
          invited: true,
        ),
        CrewMember(
          id: 'priya',
          name: 'Priya Nair',
          handle: '@priya',
          initial: 'P',
          color: Color(0xFF3E6B8A),
          invited: true,
        ),
      ],
      sessionLink: 'roadsong.app/t/cabo-trip',
      createdAt: DateTime(2026, 1, 7),
      memories: memories,
    );
  }

  Future<void> pumpApp(WidgetTester tester, TripStore store, {Key? key}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RoadSongApp(tripStore: store, key: key));
    await tester.pumpAndSettle();
  }

  Future<void> resumeToHub(WidgetTester tester) async {
    await tester.tap(find.text('Resume trip'));
    await tester.pumpAndSettle();
  }

  Future<void> openSongTab(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.music_note));
    await tester.pumpAndSettle();
  }

  /// Writes the song and lands on the lyrics stage.
  Future<void> writeSong(WidgetTester tester) async {
    await tester.tap(find.text('Write our song'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pump();
  }

  testWidgets('edit + rewrite survive screen changes and an app restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store1 = TripStore.persistent();
    await store1.init();
    await store1.addTrip(tripFixture(memories: kCaboMemories));

    await pumpApp(tester, store1);
    await resumeToHub(tester);
    await openSongTab(tester);

    // Write our song → deterministic lyrics from the trip's own content.
    await writeSong(tester);
    expect(find.text('Every Wrong Turn'), findsOneWidget);
    expect(find.textContaining('seagull for the last churro'), findsOneWidget);
    expect(find.textContaining('Maya'), findsWidgets);

    // Hand-edit the chorus.
    await tester.tap(find.byKey(const ValueKey('edit-ch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('edit-field')),
      'Our chorus, hand-written\nLine two of the chorus',
    );
    await tester.tap(find.byKey(const ValueKey('save-edit')));
    await tester.pump();
    expect(find.text('Our chorus, hand-written'), findsOneWidget);
    expect(find.text('Line two of the chorus'), findsOneWidget);

    // Rewrite verse 1: only that section re-rolls.
    await tester.tap(find.byKey(const ValueKey('rewrite-v1')));
    await tester.pump();
    expect(find.text('rewriting this part…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('rewriting this part…'), findsNothing);
    expect(find.text('Day one, Marina Pier. The plan:'), findsOneWidget);
    // The edited chorus is untouched by the rewrite.
    expect(find.text('Our chorus, hand-written'), findsOneWidget);

    // Screen change: leave the Song tab and come back — edits persist.
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();
    await openSongTab(tester);
    expect(find.text('Our chorus, hand-written'), findsOneWidget);
    expect(find.text('Day one, Marina Pier. The plan:'), findsOneWidget);

    // Restart: a fresh store instance reads the same persistence.
    final store2 = TripStore.persistent();
    await store2.init();
    expect(store2.songFor('trip-flow'), isNotNull);

    await pumpApp(tester, store2, key: const ValueKey('restart-app'));
    await resumeToHub(tester);
    await openSongTab(tester);

    // The lyrics stage resumes with the persisted draft: the hand edit and
    // the rewritten verse both survived the restart.
    expect(find.text('Every Wrong Turn'), findsOneWidget);
    expect(find.text('Our chorus, hand-written'), findsOneWidget);
    expect(find.text('Line two of the chorus'), findsOneWidget);
    expect(find.text('Day one, Marina Pier. The plan:'), findsOneWidget);
    expect(find.text('It started in Marina Pier,'), findsNothing);
  });

  testWidgets('a trip with no memories prompts to add memories first', (
    tester,
  ) async {
    final store = InMemoryTripStore(
      trips: [tripFixture()],
      activeTripId: 'trip-flow',
    );

    await pumpApp(tester, store);
    await resumeToHub(tester);
    await openSongTab(tester);

    // The start screen still pitches the song…
    expect(find.text('Write our song'), findsOneWidget);

    // …but writing it prompts for memories instead of generating nonsense.
    await tester.tap(find.text('Write our song'));
    await tester.pump();
    expect(find.text('No memories yet'), findsOneWidget);
    expect(find.textContaining('add a memory first'), findsOneWidget);
    expect(find.text('Every Wrong Turn'), findsNothing);

    // The prompt routes to the diary's add-memory surface.
    await tester.tap(find.byKey(const ValueKey('empty-add-memory')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-memory-fab')), findsOneWidget);
  });

  testWidgets('regenerating after a new memory reflects the latest content', (
    tester,
  ) async {
    final store = InMemoryTripStore(
      trips: [
        tripFixture(memories: const [kChurroMemory]),
      ],
      activeTripId: 'trip-flow',
    );

    await pumpApp(tester, store);
    await resumeToHub(tester);
    await openSongTab(tester);
    await writeSong(tester);

    // First draft knows only the churro memory.
    expect(find.textContaining('seagull for the last churro'), findsWidgets);
    expect(find.textContaining('Karaoke meltdown'), findsNothing);

    // A new memory lands (guest contribution via the store).
    await store.addMemory('trip-flow', kKaraokeMemory);
    await tester.pumpAndSettle();

    // Regenerate re-drafts from the latest content.
    await tester.tap(find.byKey(const ValueKey('regenerate-song')));
    await tester.pump();
    expect(find.text('READING 2 MEMORIES'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pump();

    expect(find.textContaining('seagull for the last churro'), findsWidgets);
    expect(find.textContaining('Karaoke meltdown'), findsWidgets);
  });
}
