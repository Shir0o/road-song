import 'package:audioplayers/audioplayers.dart';

/// The audio seam for the Choose Sound / Making Song stages (issue #29).
///
/// Screens and engines talk to this seam only — never to audioplayers
/// directly — so app-seam tests can inject a fake and CI never touches a
/// real codec or the platform audio stack. The production implementation
/// plays the bundled vibe MP3s through `audioplayers` `AssetSource`, which
/// works on iOS, Android and web.
abstract class AudioSeam {
  /// Primes [asset] for playback without making a sound. On web this is
  /// what makes the audible start gesture-proximate: the source is loaded
  /// during the Making Song pass, and [start] is called from a tap.
  Future<void> prime(String asset);

  /// Starts (or resumes) the primed audio. On web this must be reachable
  /// from a user gesture — iOS Safari otherwise blocks the audible start.
  Future<void> start();

  /// Stops playback and releases the player.
  Future<void> stop();
}

/// Production seam backed by `audioplayers`. One player instance is reused
/// for audition and playback; priming swaps the source silently.
class AudioplayersAudioSeam implements AudioSeam {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> prime(String asset) async {
    await _player.stop();
    await _player.setSourceAsset(asset);
  }

  @override
  Future<void> start() async {
    await _player.resume();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  /// Releases the underlying player. Call when the owning screen is
  /// disposed so no audio keeps playing after the stage is left.
  Future<void> dispose() async {
    await _player.dispose();
  }
}
