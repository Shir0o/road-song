import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/screens/song_tab.dart';

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

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpSongTab(
    WidgetTester tester, {
    List<TimelineMemory> memories = const [
      kChurroMemory,
      kLaundryMemory,
      kKaraokeMemory,
    ],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongTab(
            tripName: "Cabo Fail '23",
            memories: memories,
            participants: const ['Maya', 'Tom'],
          ),
        ),
      ),
    );
  }

  /// Drives the tab from the start screen into the lyrics stage.
  Future<void> pumpLyrics(WidgetTester tester) async {
    await pumpSongTab(tester);
    await tester.tap(find.text('Write our song'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pump();
  }

  testWidgets('start stage pitches the song and shows the memory count', (
    tester,
  ) async {
    await pumpSongTab(tester);

    expect(find.text('Turn your trip\ninto a song'), findsOneWidget);
    expect(find.text('written from your 3 memories'), findsOneWidget);
    expect(find.text('Write our song'), findsOneWidget);
  });

  testWidgets('start stage singularizes a one-memory trip', (tester) async {
    await pumpSongTab(tester, memories: const [kChurroMemory]);

    expect(find.text('written from your 1 memory'), findsOneWidget);
  });

  testWidgets('reading stage analyzes memories, then lands on the lyrics', (
    tester,
  ) async {
    await pumpSongTab(tester);

    await tester.tap(find.text('Write our song'));
    await tester.pump();

    // Progress screen with the reading caption and rotating messages.
    expect(find.text('READING 3 MEMORIES'), findsOneWidget);
    expect(find.text('Reading every note…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Finding the funny bits…'), findsOneWidget);

    // After the reading pass the modular lyrics view takes over.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(find.text('Every Wrong Turn'), findsOneWidget);
    expect(find.text('draft 1 · written from your 3 memories'), findsOneWidget);
    for (final String label in const [
      'Intro',
      'Verse 1',
      'Chorus',
      'Verse 2',
      'Bridge',
      'Outro',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('rewrite swaps the chorus to its alternate lines', (
    tester,
  ) async {
    await pumpLyrics(tester);

    expect(
      find.text("Sing it back on the long road through Cabo Fail '23,"),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('rewrite-ch')));
    await tester.pump();

    // While rewriting, the busy note replaces the section lines.
    expect(find.text('rewriting this part…'), findsOneWidget);
    expect(
      find.text("Sing it back on the long road through Cabo Fail '23,"),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('rewriting this part…'), findsNothing);
    expect(
      find.text("Sing it louder on the road through Cabo Fail '23,"),
      findsOneWidget,
    );
  });
  testWidgets('saving a blank edit keeps the generated lines', (tester) async {
    await pumpLyrics(tester);

    await tester.tap(find.byKey(const ValueKey('edit-ch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('edit-field')),
      '   \n\n  ',
    );
    await tester.tap(find.byKey(const ValueKey('save-edit')));
    await tester.pump();

    expect(find.byKey(const ValueKey('edit-field')), findsNothing);
    expect(
      find.text("Sing it back on the long road through Cabo Fail '23,"),
      findsOneWidget,
    );
  });

  testWidgets('rewrite ignores further taps while a rewrite is running', (
    tester,
  ) async {
    await pumpLyrics(tester);

    await tester.tap(find.byKey(const ValueKey('rewrite-ch')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rewrite-v1')));
    await tester.pump();

    expect(find.text('rewriting this part…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    // Chorus advanced, verse 1 untouched.
    expect(
      find.text("Sing it louder on the road through Cabo Fail '23,"),
      findsOneWidget,
    );
    expect(find.textContaining('It started in'), findsOneWidget);
  });

  testWidgets('edit saves hand-typed lines into the section', (tester) async {
    await pumpLyrics(tester);

    await tester.tap(find.byKey(const ValueKey('edit-ch')));
    await tester.pump();

    final TextField editField = tester.widget(
      find.byKey(const ValueKey('edit-field')),
    );
    expect(
      editField.controller!.text,
      "Sing it back on the long road through Cabo Fail '23,\n"
      'every wrong turn worth the detour,\n'
      'from Marina Pier to Karaoke Den, we held the line,\n'
      "this one's ours forevermore.",
    );

    await tester.enterText(
      find.byKey(const ValueKey('edit-field')),
      'Brand new chorus line one\nBrand new chorus line two',
    );
    await tester.tap(find.byKey(const ValueKey('save-edit')));
    await tester.pump();

    expect(find.text('Brand new chorus line one'), findsOneWidget);
    expect(find.text('Brand new chorus line two'), findsOneWidget);
    expect(
      find.text("Sing it back on the long road through Cabo Fail '23,"),
      findsNothing,
    );
  });

  testWidgets('edit cancel keeps the generated lines', (tester) async {
    await pumpLyrics(tester);

    await tester.tap(find.byKey(const ValueKey('edit-v1')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('edit-field')),
      'Scrapped rewrite',
    );
    await tester.tap(find.byKey(const ValueKey('cancel-edit')));
    await tester.pump();

    expect(find.text('Scrapped rewrite'), findsNothing);
    expect(find.textContaining('It started in'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-field')), findsNothing);
  });

  testWidgets('chat sends feedback, shows the AI typing, then the reply', (
    tester,
  ) async {
    await pumpLyrics(tester);

    await tester.enterText(
      find.byKey(const ValueKey('chat-input')),
      'make the chorus funnier',
    );
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump();

    expect(find.text('make the chorus funnier'), findsOneWidget);
    expect(find.text('•••'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('•••'), findsNothing);
    expect(
      find.text(
        'Done — I punched up the chorus and let the wrong turns do the talking.',
      ),
      findsOneWidget,
    );
    // The reply re-rolled the chorus.
    expect(
      find.text("Sing it louder on the road through Cabo Fail '23,"),
      findsOneWidget,
    );
  });

  testWidgets('chat ignores an empty message', (tester) async {
    await pumpLyrics(tester);

    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump();

    expect(find.text('•••'), findsNothing);
    expect(find.textContaining('Done —'), findsNothing);
  });

  testWidgets('choose-the-sound CTA leads to the vibe picker and back', (
    tester,
  ) async {
    await pumpLyrics(tester);

    await tester.tap(find.byKey(const ValueKey('choose-sound')));
    await tester.pump();

    expect(find.text('How should it sound?'), findsOneWidget);
    expect(find.text('Pop-Punk'), findsOneWidget);
    expect(find.text('Euro-Trash Synth'), findsOneWidget);
    expect(find.text('Sad Boy Indie'), findsOneWidget);
    expect(find.text('Acoustic Road Folk'), findsOneWidget);
    expect(find.text('Chaotic Rap'), findsOneWidget);
    // No vibe picked yet: no tempo control, CTA is inert.
    expect(find.byKey(const ValueKey('tempo-slider')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('make-song')));
    await tester.pump();
    expect(find.text('Your song is ready!'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sound-back')));
    await tester.pump();
    expect(find.text('Every Wrong Turn'), findsOneWidget);
  });

  testWidgets('picking a vibe reveals tempo control bound to its range', (
    tester,
  ) async {
    await pumpLyrics(tester);
    await tester.tap(find.byKey(const ValueKey('choose-sound')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('style-card-pop-punk')));
    await tester.pump();

    expect(find.text('♪ SELECTED'), findsOneWidget);
    expect(find.text('140–190 BPM'), findsOneWidget);
    expect(find.text('168 BPM'), findsOneWidget);
    final Slider slider = tester.widget<Slider>(
      find.byKey(const ValueKey('tempo-slider')),
    );
    expect(slider.min, 140);
    expect(slider.max, 190);
    expect(slider.value, 168);

    // Moving the slider retunes the tempo readout (tap lands mid-track).
    await tester.tap(find.byKey(const ValueKey('tempo-slider')));
    await tester.pump();
    expect(find.text('165 BPM'), findsOneWidget);

    // Switching vibes swaps the tempo window and resets to its default.
    await tester.tap(find.byKey(const ValueKey('style-card-sad-boy-indie')));
    await tester.pump();
    final Slider indieSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('tempo-slider')),
    );
    expect(indieSlider.min, 70);
    expect(indieSlider.max, 110);
    expect(find.text('92 BPM'), findsOneWidget);
  });

  testWidgets('make-song runs the synthesis pass and lands on the summary', (
    tester,
  ) async {
    await pumpLyrics(tester);
    await tester.tap(find.byKey(const ValueKey('choose-sound')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('style-card-pop-punk')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('make-song')));
    await tester.pump();

    // Making-song pass: the decided stages show in order with credible
    // timing, starting with the first stage.
    expect(find.text('Writing lyrics'), findsWidgets);
    expect(find.text('MAKING POP-PUNK AT 168 BPM'), findsOneWidget);
    expect(find.text('Arranging music'), findsOneWidget);
    expect(find.text('Mixing'), findsOneWidget);
    expect(find.text('Mastering'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Arranging music'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Mixing'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Mastering'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();

    expect(find.text('Your song is ready!'), findsOneWidget);
    expect(find.text('mastered at 168 BPM · Pop-Punk'), findsOneWidget);
    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Words aligned'), findsOneWidget);
    expect(find.text('Evidence cues'), findsOneWidget);
    expect(find.text('3'), findsWidgets, reason: 'all three Cabo memories cue');
    expect(find.text('Pop-up moments'), findsOneWidget);
    expect(find.textContaining('Marina Pier'), findsOneWidget);

    // Share Memorial Card CTA launches the keepsake and export view
    expect(find.byKey(const ValueKey('share-memorial-card')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('share-memorial-card')));
    await tester.pump();

    expect(find.text('SHARE MEMORIAL'), findsOneWidget);
    expect(find.text('KEEPSAKE'), findsOneWidget);
    expect(find.text('1080p MP4 Video Export'), findsOneWidget);

    // Back returns to the ready screen
    await tester.tap(find.byKey(const ValueKey('memorial-back-button')));
    await tester.pump();

    expect(find.text('Your song is ready!'), findsOneWidget);

    // Watch Highlight Reel CTA launches the player
    expect(find.byKey(const ValueKey('play-highlight-reel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-highlight-reel')));
    await tester.pump();

    expect(find.text('60 FPS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reel-play-pause-button')),
      findsOneWidget,
    );

    // Share from player launches memorial screen
    await tester.tap(find.byKey(const ValueKey('reel-share-button')));
    await tester.pump();

    expect(find.text('SHARE MEMORIAL'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('memorial-back-button')));
    await tester.pump();

    expect(find.text('Your song is ready!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remix-song')));
    await tester.pump();
    expect(find.text('How should it sound?'), findsOneWidget);
  });
}
