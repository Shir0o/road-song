import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/models/song_models.dart';

/// Seam B unit tests for the Making Song stage state machine and the
/// vibe → audio mapping (issue #29). Pure model tests, no UI, no audio.
void main() {
  group('MakingSongStage', () {
    test('ships the decided stage list in order', () {
      expect(
        [for (final MakingSongStage s in MakingSongStage.stages) s.id],
        ['writing', 'arranging', 'mixing', 'mastering'],
      );
      expect(
        [for (final MakingSongStage s in MakingSongStage.stages) s.label],
        ['Writing lyrics', 'Arranging music', 'Mixing', 'Mastering'],
      );
    });

    test('every stage has a credible positive duration', () {
      expect(
        MakingSongStage.stageDurations.length,
        MakingSongStage.stages.length,
      );
      for (final Duration d in MakingSongStage.stageDurations) {
        expect(d, greaterThan(Duration.zero));
      }
    });

    test('total duration is the sum of the stage durations', () {
      Duration sum = Duration.zero;
      for (final Duration d in MakingSongStage.stageDurations) {
        sum += d;
      }
      expect(MakingSongStage.totalDuration, sum);
    });
  });

  group('SongArtifact stage state machine', () {
    test('is locked until the pass completes, then unlocks', () {
      final SongArtifact artifact = SongArtifact(
        styleId: 'pop-punk',
        audioAsset: 'audio/vibes/pop_punk.mp3',
        bpm: 168,
      );
      expect(artifact.isUnlocked, isFalse);

      final SongArtifact done = artifact.copyWith(
        stageIndex: MakingSongStage.stages.length,
      );
      expect(done.isUnlocked, isTrue);
    });

    test('copyWith advances the stage without touching the vibe', () {
      final SongArtifact artifact = SongArtifact(
        styleId: 'sad-boy-indie',
        audioAsset: 'audio/vibes/sad_boy_indie.mp3',
        bpm: 92,
      );
      final SongArtifact next = artifact.copyWith(stageIndex: 1);
      expect(next.styleId, 'sad-boy-indie');
      expect(next.audioAsset, 'audio/vibes/sad_boy_indie.mp3');
      expect(next.bpm, 92);
      expect(next.stageIndex, 1);
    });

    test('resolves its vibe from the catalog', () {
      final SongArtifact artifact = SongArtifact(
        styleId: 'pop-punk',
        audioAsset: 'audio/vibes/pop_punk.mp3',
        bpm: 168,
        stageIndex: MakingSongStage.stages.length,
      );
      expect(artifact.style?.label, 'Pop-Punk');
    });

    test('round-trips through JSON', () {
      final SongArtifact artifact = SongArtifact(
        styleId: 'chaotic-rap',
        audioAsset: 'audio/vibes/chaotic_rap.mp3',
        bpm: 144,
        stageIndex: 2,
      );
      final SongArtifact restored = SongArtifact.fromJson(artifact.toJson());
      expect(restored.styleId, artifact.styleId);
      expect(restored.audioAsset, artifact.audioAsset);
      expect(restored.bpm, artifact.bpm);
      expect(restored.stageIndex, artifact.stageIndex);
    });
  });

  group('vibe → audio mapping', () {
    test('every catalog vibe ships a distinct bundled audition asset', () {
      final Set<String> assets = <String>{};
      for (final MusicalStyle style in MusicalStyle.catalog) {
        expect(style.audioAsset, isNotEmpty);
        expect(style.audioAsset, endsWith('.mp3'));
        assets.add(style.audioAsset);
      }
      // One distinct track per vibe — the audition must sound different.
      expect(assets.length, MusicalStyle.catalog.length);
    });

    test('each vibe maps to its own asset', () {
      MusicalStyle styleOf(String id) =>
          MusicalStyle.catalog.firstWhere((MusicalStyle s) => s.id == id);
      expect(styleOf('pop-punk').audioAsset, 'audio/vibes/pop_punk.mp3');
      expect(
        styleOf('euro-trash-synth').audioAsset,
        'audio/vibes/euro_trash_synth.mp3',
      );
      expect(
        styleOf('sad-boy-indie').audioAsset,
        'audio/vibes/sad_boy_indie.mp3',
      );
      expect(
        styleOf('acoustic-road-folk').audioAsset,
        'audio/vibes/acoustic_road_folk.mp3',
      );
      expect(styleOf('chaotic-rap').audioAsset, 'audio/vibes/chaotic_rap.mp3');
    });
  });
}
