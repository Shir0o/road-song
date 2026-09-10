import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_song/main.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/services/audio_seam.dart';
import 'package:road_song/services/trip_store.dart';

/// Seam A flow tests for the Choose Sound / Making Song / audio journey
/// (issue #29): pump the real app with an injected in-memory TripStore and a
/// fake audio seam, then drive choose vibe → audition (mocked) → add to the
/// memorial → staged pass (fast-forwarded) → song unlocked → play (mocked) →
/// remake keeps lyrics.
class FakeAudioSeam implements AudioSeam {
  final List<String> primed = [];
  final List<String> started = [];
  int stopCount = 0;

  @override
  Future<void> prime(String asset) async {
    primed.add(asset);
  }

  @override
  Future<void> start() async {
    started.add(primed.isEmpty ? '' : primed.last);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

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
    id: 'trip-audio',
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
    memories: memories,
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpApp(
    WidgetTester tester,
    TripStore store,
    FakeAudioSeam audio, {
    Key? key,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RoadSongApp(tripStore: store, audioSeam: audio, key: key),
    );
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

  /// Drives the full Making Song pass (fast-forwarded) and lands on ready.
  Future<void> makeSong(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('make-song')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4500));
    await tester.pump();
  }

  testWidgets(
    'choose vibe → audition → staged pass → unlocked song → play → remake '
    'keeps lyrics',
    (tester) async {
      final store = InMemoryTripStore(
        trips: [tripFixture(memories: kCaboMemories)],
        activeTripId: 'trip-audio',
      );
      final audio = FakeAudioSeam();

      await pumpApp(tester, store, audio);
      await resumeToHub(tester);
      await openSongTab(tester);
      await writeSong(tester);

      // Choose Sound: the fixed vibe set renders.
      await tester.ensureVisible(find.byKey(const ValueKey('choose-sound')));
      await tester.tap(find.byKey(const ValueKey('choose-sound')));
      await tester.pump();
      expect(find.text('How should it sound?'), findsOneWidget);
      for (final MusicalStyle style in MusicalStyle.catalog) {
        expect(find.text(style.label), findsOneWidget);
      }

      // Tapping a vibe auditions its own track through the audio seam.
      await tester.tap(find.byKey(const ValueKey('style-card-pop-punk')));
      await tester.pump();
      expect(audio.primed, contains('audio/vibes/pop_punk.mp3'));
      expect(audio.started, contains('audio/vibes/pop_punk.mp3'));

      // The explicit preview button re-plays the selected vibe.
      await tester.tap(find.byKey(const ValueKey('audition-vibe')));
      await tester.pump();
      expect(audio.started.length, 2);

      // Add to the memorial: the staged pass runs in order, then unlocks.
      await makeSong(tester);
      expect(find.text('Your song is ready!'), findsOneWidget);
      expect(find.text('mastered at 168 BPM · Pop-Punk'), findsOneWidget);

      // The artifact (vibe, audio ref, stage state) persisted through the
      // store seam, unlocked.
      final SongArtifact? artifact = store.songArtifactFor('trip-audio');
      expect(artifact, isNotNull);
      expect(artifact!.styleId, 'pop-punk');
      expect(artifact.audioAsset, 'audio/vibes/pop_punk.mp3');
      expect(artifact.bpm, 168);
      expect(artifact.isUnlocked, isTrue);

      // Play the song: the audible start derives from this tap.
      await tester.tap(find.byKey(const ValueKey('play-song')));
      await tester.pump();
      expect(find.text('Pop-Punk · 168 BPM'), findsOneWidget);
      expect(audio.started.last, 'audio/vibes/pop_punk.mp3');

      // Stop returns to the ready stage.
      await tester.tap(find.byKey(const ValueKey('stop-song')));
      await tester.pump();
      expect(find.text('Your song is ready!'), findsOneWidget);
      expect(audio.stopCount, 1);

      // Remake with a different vibe: re-run the pass, swap the audio, and
      // keep the lyrics.
      await tester.tap(find.byKey(const ValueKey('remix-song')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('style-card-sad-boy-indie')));
      await tester.pump();
      await makeSong(tester);

      expect(find.text('mastered at 92 BPM · Sad Boy Indie'), findsOneWidget);
      final SongArtifact? remade = store.songArtifactFor('trip-audio');
      expect(remade!.styleId, 'sad-boy-indie');
      expect(remade.audioAsset, 'audio/vibes/sad_boy_indie.mp3');
      // The lyrics from #28 are untouched by the remake.
      expect(store.songFor('trip-audio'), isNotNull);
      expect(find.text('Every Wrong Turn'), findsNothing); // on ready stage
      await tester.tap(find.byKey(const ValueKey('sound-back')));
      await tester.pump();
      expect(find.text('Every Wrong Turn'), findsOneWidget);
    },
  );

  testWidgets('a finished song resumes unlocked after an app restart', (
    tester,
  ) async {
    final store = InMemoryTripStore(
      trips: [tripFixture(memories: kCaboMemories)],
      activeTripId: 'trip-audio',
    );
    final audio = FakeAudioSeam();

    await pumpApp(tester, store, audio);
    await resumeToHub(tester);
    await openSongTab(tester);
    await writeSong(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('choose-sound')));
    await tester.tap(find.byKey(const ValueKey('choose-sound')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('style-card-pop-punk')));
    await tester.pump();
    await makeSong(tester);
    expect(find.text('Your song is ready!'), findsOneWidget);

    // Restart: a fresh app instance reads the same store.
    await pumpApp(
      tester,
      store,
      audio,
      key: const ValueKey('restart-audio-app'),
    );
    await resumeToHub(tester);
    await openSongTab(tester);

    // The unlocked song resumes on the ready stage without re-running the
    // Making Song pass.
    expect(find.text('Your song is ready!'), findsOneWidget);
    expect(find.text('mastered at 168 BPM · Pop-Punk'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-song')));
    await tester.pump();
    expect(find.text('Pop-Punk · 168 BPM'), findsOneWidget);
  });
}
