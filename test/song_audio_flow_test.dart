import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_song/main.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/services/audio_seam.dart';
import 'package:road_song/services/remote_trip_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

/// Seam A flow tests for the Choose Sound / Making Song / audio journey
/// (issue #29): pump the real app with an injected in-memory TripStore and a
/// fake audio seam, then drive choose vibe → audition (mocked) → add to the
/// memorial → staged pass (fast-forwarded) → song unlocked → play (mocked) →
/// remake keeps lyrics.
class FakeAudioSeam implements AudioSeam {
  final List<String> primed = [];
  final List<String> started = [];
  final List<Duration> seeks = [];
  int stopCount = 0;
  int pauseCount = 0;

  /// Emitted position while "playing" — tests drive the player clock with
  /// these to simulate real playback.
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
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

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

      // Play the song: the audible start derives from this tap and the
      // kinetic player opens.
      await tester.tap(find.byKey(const ValueKey('play-song')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('kinetic-play-pause-button')),
        findsOneWidget,
      );
      expect(find.text('168 BPM · POP-PUNK'), findsOneWidget);
      expect(audio.started.last, 'audio/vibes/pop_punk.mp3');

      // Close returns to the ready stage.
      await tester.tap(find.byKey(const ValueKey('kinetic-close-button')));
      await tester.pump();
      expect(find.text('Your song is ready!'), findsOneWidget);

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
    expect(
      find.byKey(const ValueKey('kinetic-play-pause-button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'kinetic player: play/pause, seek and replay drive the audio seam and '
    'the line-level cues',
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
      await tester.ensureVisible(find.byKey(const ValueKey('choose-sound')));
      await tester.tap(find.byKey(const ValueKey('choose-sound')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('style-card-pop-punk')));
      await tester.pump();
      await makeSong(tester);
      expect(find.text('Your song is ready!'), findsOneWidget);

      // Open the kinetic player: the audible start derives from this tap.
      await tester.tap(find.byKey(const ValueKey('play-song')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('kinetic-play-pause-button')),
        findsOneWidget,
      );
      expect(audio.started.last, 'audio/vibes/pop_punk.mp3');

      // The line-level cue strip shows the active section marker and line.
      expect(find.byKey(const ValueKey('line-cue-strip')), findsOneWidget);

      // Pause: the audio seam pauses and the ticker stops.
      await tester.tap(find.byKey(const ValueKey('kinetic-play-pause-button')));
      await tester.pump();
      expect(audio.pauseCount, 1);
      expect(find.text('❚❚ PAUSED'), findsOneWidget);

      // Resume: the audio seam starts again (vibe audition + play + resume).
      await tester.tap(find.byKey(const ValueKey('kinetic-play-pause-button')));
      await tester.pump();
      expect(audio.started.length, 3);
      expect(audio.started.last, 'audio/vibes/pop_punk.mp3');
      expect(find.text('● TAPE PLAYING'), findsOneWidget);

      // Seek: dragging the scrubber seeks the audio seam.
      final Finder slider = find.byKey(
        const ValueKey('kinetic-scrubber-slider'),
      );
      await tester.tap(slider);
      await tester.pump();
      expect(audio.seeks, isNotEmpty);

      // Replay: seeks back to zero and keeps playing.
      await tester.tap(find.byKey(const ValueKey('kinetic-replay-button')));
      await tester.pump();
      expect(audio.seeks.last, Duration.zero);
      expect(find.textContaining('0:00 /'), findsOneWidget);

      // Close returns to the ready stage.
      await tester.tap(find.byKey(const ValueKey('kinetic-close-button')));
      await tester.pump();
      expect(find.text('Your song is ready!'), findsOneWidget);
    },
  );

  testWidgets(
    'ready state surfaces the share action; the shared link is the trip link',
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
      await tester.ensureVisible(find.byKey(const ValueKey('choose-sound')));
      await tester.tap(find.byKey(const ValueKey('choose-sound')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('style-card-pop-punk')));
      await tester.pump();
      await makeSong(tester);

      // The ready state surfaces the share action.
      expect(find.text('Your song is ready!'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-memorial-link')), findsOneWidget);

      // The ready screen shows the trip link (roadsong.app/t/<code>).
      await tester.tap(find.byKey(const ValueKey('share-memorial-link')));
      await tester.pump();
      expect(find.text('Your trip memorial is ready'), findsOneWidget);
      expect(find.text('roadsong.app/t/cabo-trip'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-memorial-link')), findsOneWidget);
    },
  );

  testWidgets(
    'a remote-backed trip publishes the memorial so the link serves it',
    (tester) async {
      final FakeBackend backend = FakeBackend();
      final Trip trip = await backend.createTrip(
        const TripDraft(name: 'Cabo Trip'),
      );
      final RemoteTripStore store = RemoteTripStore(
        client: backend,
        pollInterval: const Duration(seconds: 10),
      );
      await store.addTrip(trip.copyWith(memories: kCaboMemories));
      await store.init();
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

      // The finished memorial was published to the backend: a visitor
      // opening the trip link can fetch it (audio ref + lyrics + timeline).
      final MemorialSong? served = await backend.fetchSong(trip.code);
      expect(served, isNotNull);
      expect(served!.title, 'Every Wrong Turn');
      expect(served.audioAsset, 'audio/vibes/pop_punk.mp3');
      expect(served.lyrics, isNotEmpty);
      expect(served.sections, isNotEmpty);
      expect(
        served.sections.first.lines.first.startMs,
        greaterThanOrEqualTo(0),
      );

      // Stop the poll timer before the test body ends.
      store.dispose();
    },
  );

  testWidgets(
    'restart preserves the finished-memorial state through the store seam',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store1 = TripStore.persistent();
      await store1.init();
      await store1.addTrip(tripFixture(memories: kCaboMemories));
      final audio = FakeAudioSeam();

      await pumpApp(tester, store1, audio);
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

      // Restart: a fresh persistent store reads the same preferences.
      final store2 = TripStore.persistent();
      await store2.init();
      expect(store2.songArtifactFor('trip-audio')?.isUnlocked, isTrue);

      await pumpApp(
        tester,
        store2,
        audio,
        key: const ValueKey('restart-finished'),
      );
      await resumeToHub(tester);
      await openSongTab(tester);

      // The finished memorial resumes: ready state, playable player, and
      // the share action all return without re-running the pass.
      expect(find.text('Your song is ready!'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('play-song')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('kinetic-play-pause-button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('kinetic-close-button')));
      await tester.pump();
      expect(find.byKey(const ValueKey('share-memorial-link')), findsOneWidget);
    },
  );
}
