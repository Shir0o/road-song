# Research: simulated-song audio on iOS + Android + Flutter web (v1)

Date: 2026-09-04 · Issue: [Shir0o/road-song#15](https://github.com/Shir0o/road-song/issues/15) → feeds decision [#18](https://github.com/Shir0o/road-song/issues/18)
Scope: in-app player only (no export, no background service); ~60–90 s "song" that starts after a fake staged "Making Song" delay, then plays in the memorial player with lyric karaoke. No real AI-music service. Current code plays ElevenLabs bytes through `audioplayers` `BytesSource` (see `lib/screens/banger_screen.dart`, `_generateMusicWithElevenLabs`).

---

## Recommendation

**Option 2 — bundle a small set of royalty-free MP3 tracks (one per vibe, 4 vibes today) and play them as assets through `audioplayers` (`AssetSource`).** It is the only option whose output is guaranteed to *sound like a real song* — the whole point of the demo moment — at near-zero engineering cost, with a licensing burden that is manageable and auditable. Procedural WAV synthesis in Dart (Option 1) is the fallback if any licensing concern becomes a blocker; it is credible and cheap enough (runs inside the fake generation delay), but "sounds acceptable" is the risky, unbounded part. Web Audio via `dart:js_interop` (Option 3) is **not recommended**: it duplicates synthesis logic for one platform and adds autoplay-policy failure modes without solving anything Option 1 doesn't already solve with the same `audioplayers` API.

Hard-constraint verdicts, in one line each:

| Constraint | Verdict |
|---|---|
| audioplayers codecs | Plugin supports whatever the platform player decodes; MP3 and 16-bit PCM WAV are safe on all 3 targets. |
| Web autoplay policy | A *timer-triggered* auto-start (current code) is blocked on iOS Safari and risky on desktop; audible start must be reachable via a user gesture (a tap) — native is unaffected. |
| iOS silent switch | audioplayers defaults to `.playback` category → audio is NOT silenced by the Ring/Silent switch. Nothing to do. |
| Android audio focus | Default `AUDIOFOCUS_GAIN` + `USAGE_MEDIA`; transient loss pauses & resumes, permanent loss pauses. Nothing to do. |
| File size (60–90 s) | MP3 @128 kbps ≈ 0.96–1.44 MB per track; @96 kbps ≈ 0.72–1.08 MB. 16-bit 44.1 kHz WAV ≈ 10.6–15.9 MB stereo / 5.3–7.9 MB mono. |
| Playback after fake delay | Works on all options; on web, prime the source during the delay and gate the audible start on a gesture (see "Making-Song illusion" below). |

---

## 1. Ground truth about the current stack (audioplayers)

Repo pins `audioplayers: ^6.0.0`. Latest release is **6.8.1** (pub.dev, checked 2026-09-04); source facts below are from the bluefireteam/audioplayers repo at commit `cd475c7` (2026-07-23), matching the 6.x line.

### 1.1 Formats: the plugin plays what the platform plays
audioplayers' own troubleshooting doc: "Not all formats are supported by all platforms… [use] a list of supported formats" → Android: [Supported media formats](https://developer.android.com/media/platform/supported-formats), macOS/iOS: Core Audio formats, **Web: "audio formats supported by the browser you are using"** ([MDN audio codec guide](https://developer.mozilla.org/en-US/docs/Web/Media/Formats/Audio_codecs)). Source: https://github.com/bluefireteam/audioplayers/blob/main/troubleshooting.md

Platform decode facts (primary):

- **Android** (`android.media.MediaPlayer` is the default — `PlayerMode.MEDIA_PLAYER` in `WrappedPlayer.kt:89`): platform table says **MP3: decoder YES (.mp3, mono/stereo, 8–320 kbps CBR/VBR)**, **PCM/WAVE: decoder YES (WAVE .wav, 8- and 16-bit linear PCM)**, AAC LC YES, Vorbis YES, Opus (5.0+) YES. WAV must be **integer PCM** (16-bit is the safe target). [Android supported media formats](https://developer.android.com/media/platform/supported-formats)
- **iOS**: the darwin plugin wraps `AVPlayer` (`WrappedMediaPlayer.swift`); Apple does not publish an exhaustive codec table for AVPlayer, but MP3/AAC/M4A/16-bit WAV are system-decoded, industry-standard formats. *[INFERENCE] treat as safe and confirm once on a device — no Apple list exists to cite.*
- **Web**: decode happens in the browser's `<audio>` element. MP3 and 16-bit PCM WAV decode in every evergreen browser incl. iOS Safari; MP3 is the safest single choice. audioplayers does no decoding of its own on web.

### 1.2 How each Source type is realized per platform (from source)

`packages/audioplayers/lib/src/audioplayer.dart`:

- **`AssetSource`** (`setSourceAsset`) → `audioCache.loadPath(path)` copies the asset to a temp file on mobile (once), then plays that path; on web the asset URL is used directly (Flutter serves `assets/…`).
- **`BytesSource`** (`setSourceBytes`, lines ~606–627):
  - **iOS/macOS/Linux**: writes bytes to a temp file (`getTemporaryDirectory()`, name = hash of bytes) and plays the file. Re-calling with new bytes rewrites the file.
  - **Android**: `_platform.setSourceBytes` → `BytesSource.kt` uses an in-memory `MediaDataSource` (`mediaPlayer.setDataSource(dataSource)`; requires API 23+ — plugin minSdk is 19, so guard/behavior on <23 exists but is irrelevant for any modern device).
  - **Web**: `audioplayers_web/lib/audioplayers_web.dart` → `Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg' default)` — i.e. a **base64 data URI** becomes the `<audio>` `src`. A 15 MB WAV becomes a ~20 MB base64 string held in JS memory. Pass `mimeType:` explicitly when feeding WAV bytes.

### 1.3 Web implementation + autoplay behavior (source-level)

`packages/audioplayers_web/lib/wrapped_player.dart`:

- Each player creates a single `HTMLAudioElement` (`preload = 'auto'`, `crossOrigin = 'anonymous'`) **and routes it through a Web Audio `AudioContext`** (`createMediaElementSource` → gain → panner → destination). Consequences:
  - Sound only reaches the speakers if that `AudioContext` is **running**.
  - `start()` (called by `play()`/`resume()`) does: `if (_audioContext.state == 'suspended') await _audioContext.resume(); … await player?.play()`. Code comment in source: *"Safari requires explicit resume after user gesture"*.
- So audible playback on web depends on the browser autoplay policy for **both** `AudioContext.resume()` and `HTMLMediaElement.play()`.

Browser policy (primary):

- **Chrome**: autoplay *with sound* is allowed once "the user has interacted with the domain (click, tap, etc.)"; muted autoplay always allowed; a `play()` without any prior interaction rejects with `NotAllowedError`. Web Audio is covered since Chrome 71; a context created on page load can be resumed "at some time after the user interacted with the page". [Chrome autoplay policy](https://developer.chrome.com/blog/autoplay/)
- **WebKit/Safari (incl. iOS)**: audible media and audio contexts require a **user gesture**, and WebKit's definition is strict — "the JavaScript which resulted in the call to `video.play()`… must have directly resulted from a handler for a `touchend`, `click`, `doubleclick`, or `keydown` event. So `button.addEventListener('click', () => { video.play(); })` would satisfy… `video.addEventListener('canplaythrough', …)` would not." ([WebKit, New <video> Policies for iOS](https://webkit.org/blog/6784/new-video-policies-for-ios/)). The same model governs `<audio>` and `AudioContext` on iOS; an async gap (`await`, `setTimeout`, `Timer`) between the gesture and the play/resume call is the classic way to lose it.
- **General**: MDN — playback initiated programmatically "in a tab which has not yet had any user interaction" is generally blocked; interaction, muted audio, or allowlisting enable it. [MDN Autoplay guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay)

**Practical consequence for this app:** the current pattern — tap "Make song" → 3 s fake progress `Timer` → `await _audioPlayer.play(...)` fires from the timer callback, i.e. **outside the original gesture handler** — is exactly the case WebKit blocks on iOS Safari, and it can also fail in Chrome/Firefox if no tap happened earlier in the page session. Native iOS/Android have **no** user-gesture rule for in-app `AVPlayer`/`MediaPlayer`, so this is a web-only (but real) hazard — *the current ElevenLabs flow is likely already silent-on-web on first run*.

### 1.4 iOS audio session / silent switch

- audioplayers' darwin plugin uses a **global `AudioContext()` whose default category is `.playback` with no options** (`AudioContext.swift` init), applied on plugin setup and re-applied on changes; it calls `session.setActive(anyIsPlaying)` while playing (`AudioplayersDarwinPlugin.swift:41/129/320/392`).
- Apple: with the default audio session, "Ring/Silent switch set to silent mode in iOS silences app audio"; with **`.playback`**, "the system doesn't silence your app's audio when someone sets the Ring/Silent switch to silent mode in iOS only" — i.e. the fake song is **audible in silent mode** out of the box, and playback pauses other background audio (no `mixWithOthers`). [Apple: Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)
- **No background mode is needed** (and none is configured): playback is in-app; if the user backgrounds the app mid-song, iOS suspends the app and audio stops — acceptable per v1 scope. If foreground-only is the requirement, nothing else to do.

### 1.5 Android audio focus

- Default context (`AudioContextAndroid.kt`): `usageType = USAGE_MEDIA`, `contentType = CONTENT_TYPE_MUSIC`, `audioFocus = AUDIOFOCUS_GAIN`, `audioMode = MODE_NORMAL`.
- `FocusManager.kt`: on focus **grant** → (re)start if playing; on **transient loss** (calls, navigation prompts) → pause, auto-resume on regain; on **permanent loss** → pause, no auto-resume. `AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK` is deliberately ignored (system ducks). Android 12+ adds system-enforced fade-out of other apps when focus is gained, and mutes other apps during incoming calls. [Android: Manage audio focus](https://developer.android.com/media/optimize/audio-focus)
- Net: correct, conventional music-app behavior with zero configuration.

---

## 2. Option-by-option analysis

### Option 1 — Procedural synthesis in Dart (WAV in code)

Beats/chords/melody written as a small sequencer that renders a 16-bit PCM WAV (`Uint8List`), handed to the *same* `BytesSource` path already in the code. Library-free is realistic: the WAV header is 44 fixed bytes — no package needed; `package:wav` is optional sugar. No established "Dart synth" package is worth adding (none is a credible music engine; *[INFERENCE] based on pub.dev ecosystem knowledge — verify if pursued*).

- **Effort to sound acceptable: HIGH (the unbounded part).** Drum machine + bass + chord pad + simple lead at fixed BPM is achievable in a few hundred lines, but "sounds like a produced demo song rather than a ringtone" needs real iteration (mixing levels, velocity, a chord progression per vibe, arrangement/energy arc, reverb-ish tail). Budget as an open-ended taste task, not a plumbing task.
- **CPU on device:** trivially fine. Work ≈ samples × voices. Worst case ~44.1 kHz × 2 ch × 90 s ≈ 7.9 M frames × ~10 voices ≈ 80 M adds/sin calls. Release (AOT) Dart on any modern phone: well under ~1–2 s; **debug/JIT builds can be ~5–10× slower (seconds)**. Cheap mitigations: 22.05 kHz, mono, precomputed wavetables instead of `sin()`, or render during the staged "Making Song" delay (below) so the cost is invisible. *[INFERENCE: order-of-magnitude estimate; measure once in a release build if this option is chosen.]*
- **Memory:** 16-bit 44.1 kHz stereo × 90 s = **15.9 MB** `Uint8List`; mono 22.05 kHz = **4.0 MB**. Android plays it in-memory via `MediaDataSource` (no disk); iOS writes a temp file (~15 MB disk, transient); web base64-encodes it (~20 MB string, transient) — all acceptable on modern phones, but web is the worst case (see 1.2).
- **Plausibility of the result:** a synthesized instrumental "bed" is credible *if* the product accepts instrumental + lyric-karaoke as the "song". It will not fool anyone into thinking a real band recorded it; for a memorial "wow" moment that matters.
- **Making-Song illusion:** excellent — synthesis runs *during* the staged delay, and the bytes exist only when the fake progress completes. `BytesSource` after the flip is a ~100 ms–1 s local prepare (decode/load), so start can follow the delay closely. Deterministic: same vibe → same audio (cacheable, or re-render per trip).
- **Licensing: none.** This is its only unambiguous win.

### Option 2 — Bundled royalty-free tracks (RECOMMENDED)

One (or a few) small MP3s selected by vibe. The app has **4 vibes** today (`Pop-Punk (2000s)`, `Euro-Trash Synth`, `Sad Boy Indie`, `Chaotic Rap` — `banger_screen.dart:36-41`), so a credible set is 1 track per vibe (~4 files), re-encoded/trimmed to the target length.

- **File size / download impact:** MP3 @128 kbps CBR: **0.96 MB (60 s) / 1.44 MB (90 s)** per track; @96 kbps: 0.72 / 1.08 MB. Four tracks @~75 s ≈ **3–4.5 MB** added to the app bundle — negligible for IPA/APK/AAB and for a Flutter-web deploy. WAV would be 10–16 MB/track — do not bundle WAV. (Sizes are arithmetic: bytes = bitrate/8 × seconds.)
- **Codec/playback:** MP3 decodes on Android `MediaPlayer` (YES in the platform table), iOS `AVPlayer`, and every evergreen browser's `<audio>` (see §1.1). Play via `AssetSource` → same API as today, works on all 3 platforms with one code path; **no `BytesSource`, no data-URI tax on web**; ~1 MB assets load from the bundle instantly.
- **Web codec support:** MP3 is the safest universal container (AAC/M4A is also universal in practice; avoid Ogg Vorbis/Opus if iOS Safari must play it — container support gaps). If a track ships as WAV source, transcode to MP3 CBR 128 for the asset.
- **Licensing for a demo product:** choose tracks whose license permits app embedding without per-sale royalties. Primary options:
  - **Pixabay Music** — verified current Content License summary: free use, **no attribution required**, modify/adapt allowed; prohibited uses are standalone redistribution ("no creative effort applied"), trademark/merchandise use, misleading use. Embedding a track inside an app as part of the experience is squarely allowed. Full terms are the binding document. https://pixabay.com/service/license-summary/
  - **CC0 / Public Domain catalogs** — cleanest legally. Note: **FreePD.com is CLOSED** (site shows a closure notice as of 2026) — do not plan around it. Other CC0 sources (e.g. ccMixter CC0-filtered, archive.org collections) need per-track diligence.
  - **Kevin MacLeod / incompetech** — historically CC BY 4.0 (attribution required, commercial OK); site is JS-rendered, verify the current license text per track before relying on it.
  - Avoid NC/ND variants (ND forbids the trim/loop edits you need).
  - **Audit trail:** keep a `THIRD_PARTY_NOTICES.md`/asset manifest recording per-track: source URL, download date, license name + URL, author. For a demo that could later ship commercially this is the whole ballgame.
- **Making-Song illusion:** excellent with one pattern: `await player.setSource(AssetSource(vibeTrack))` when the fake generation starts (prepare silently, and let `onDurationChanged` arrive during the progress stage), then start audio on flip via `resume()` (native) or a user-gesture tap (web, see §4). `setSource` alone produces no sound.
- **Risks:** (a) real-world duration is fixed by the track — karaoke timeline should be derived from the loaded asset's actual duration (the code already normalizes lyric index from `_audioDuration`), and/or the track is trimmed to a canonical length so the "60–90 s" claim holds; (b) instruments only — no vocals — acceptable because karaoke is lyric-highlight over a bed, but set expectations; (c) license diligence is manual.

### Option 3 — Web Audio API via `dart:js_interop` (web only)

Synthesize with `OscillatorNode`/`AudioBufferSourceNode` graphs on Flutter web, falling back to WAV/bundled on native.

- **Advantages:** zero asset bytes on web; per-sample control is richer than rendered WAV (live envelopes/filters).
- **Disadvantages (why not):** you would maintain **two synthesis implementations** (Dart renderer + JS graph) or fork code per platform; it inherits the same autoplay/user-gesture rules as audioplayers' web path (§1.3) with *stricter* timing (context must be resumed inside a gesture); scheduling a 60–90 s arrangement against a fake staged delay means building a clock/transport by hand; and audioplayers on web already occupies one `AudioContext` per player (iOS Safari additionally caps concurrent contexts). All benefits are obtainable from Option 1's bytes through the existing, uniform `audioplayers` API.
- **Verdict: reject for v1.** Revisit only if a future real (non-fake) generator needs live, low-latency DSP on web.

---

## 3. Making-Song illusion & preloading (all options)

The requirement — *audible only after the fake staged-progress delay* — is satisfiable everywhere, and the recipe is the same:

1. **Native (iOS/Android):** no autoplay restriction exists for in-app players. Start `setSource` when the fake generation stage begins (prime/decode during the animation), then `resume()` at the stage flip; or simply `play(source)` at the flip. Either way playback begins only after the delay, with no audible leak during it.
2. **Web:** the danger is the reverse — *too little* gesture proximity. Prime (`setSource`) during the delay (loading is allowed anytime; no sound), then start audio from a **user gesture that occurs at/after the flip** — the playback screen already has a play/pause control and a vinyl button. If auto-start from the timer is desired, wrap the start in a `try/catch` on `NotAllowedError`/`PlatformException` and fall back to "tap to play"; never leave a spinner claiming playback that the browser blocked. Treat iOS Safari as the strict case (WebKit quote in §1.3); Chrome is satisfied by any earlier interaction with the page.
3. **Karaoke alignment:** derive the lyric index mapping from the real `onDurationChanged` (already the pattern in `banger_screen.dart`); for bundled tracks this means the fake timeline is normalized to the actual track length, so trim each asset to a canonical 60–90 s.

Preloading implication: bundled assets (~1 MB) and locally synthesized WAV need no network preload; `BytesSource` on web materializes a base64 string only when set — keep priming on web to `AssetSource` if Option 2 is chosen.

---

## 4. Risks & limits

- **Web silent-audio is the #1 real risk** for *every* option, including today's code: any play()/resume() that is not gesture-proximate can be blocked (iOS Safari strictest; Chrome only before first interaction; Firefox per user setting). Mitigation above; verify on a real iOS Safari session.
- **WAV format trap:** Android `MediaPlayer` and browsers want **integer PCM** (16-bit); do not emit float WAV from a Dart synth.
- **BytesSource on web** should be avoided for large buffers (data-URI base64 of 15–20 MB) — prefer `AssetSource` for pre-made audio; if Option 1 is chosen on web, consider a lower-rate mono WAV (~2.6–4.0 MB) to keep the URI sane, or write the synth output to a same-origin Blob URL via `dart:js_interop` instead of the base64 path.
- **iOS suspension:** no background mode → audio stops if the app is backgrounded (in scope by design).
- **Android focus behaviors:** interruptions pause and transient ones auto-resume — expected, but the UI's play state should follow `onPlayerComplete`/pause streams (already wired).
- **License diligence** is on the human; keep the manifest even for a demo.
- **"Sounds acceptable"** is only guaranteed by Option 2; Options 1/3 carry open-ended audio-quality risk.

## 5. Facts for decision #18 (condensed)

- Use **bundled MP3 @96–128 kbps CBR, ~60–90 s, one per vibe (4)** via `audioplayers` `AssetSource`; expect **~3–4.5 MB** total. Fallback: Dart-rendered **16-bit PCM WAV** (mono 22.05–44.1 kHz) via `BytesSource`, rendered during the fake delay; ~2.6–15.9 MB memory/disk depending on format.
- No iOS silent-switch, session, or Android focus work needed (audioplayers defaults: `.playback` category; `AUDIOFOCUS_GAIN` + `USAGE_MEDIA`).
- Web: prime during delay, start from a user gesture; handle the rejection path. Do not auto-play from a `Timer` on web.
- MP3 plays on all three targets; WAV must be integer PCM; Ogg/Opus unsuitable for iOS Safari as a web target; licensing: Pixabay license (verified) or CC0 with per-track provenance; FreePD defunct.

## Sources (accessed 2026-09-04)

- audioplayers source (6.x line, commit cd475c7, 2026-07-23): `audioplayer.dart` (source resolution), `audioplayers_web/lib/*` (web player, data-URI bytes, AudioContext resume), `AudioplayersDarwinPlugin.swift`/`AudioContext.swift` (iOS `.playback` default), `AudioContextAndroid.kt`/`FocusManager.kt`/`WrappedPlayer.kt`/`BytesSource.kt` (Android focus + bytes). https://github.com/bluefireteam/audioplayers
- audioplayers troubleshooting (formats = platform; web = browser): https://github.com/bluefireteam/audioplayers/blob/main/troubleshooting.md
- audioplayers on pub.dev (latest 6.8.1): https://pub.dev/packages/audioplayers
- Android supported media formats (MP3/PCM-WAVE/AAC decode table): https://developer.android.com/media/platform/supported-formats
- Android audio focus: https://developer.android.com/media/optimize/audio-focus
- Apple — Configuring your app for media playback (.playback vs Ring/Silent switch): https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback
- Chrome autoplay policy: https://developer.chrome.com/blog/autoplay/
- WebKit — New `<video>` Policies for iOS (user-gesture rule): https://webkit.org/blog/6784/new-video-policies-for-ios/
- MDN autoplay guide: https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay
- MDN audio codec guide: https://developer.mozilla.org/en-US/docs/Web/Media/Formats/Audio_codecs
- Pixabay Content License summary (verified live): https://pixabay.com/service/license-summary/
- FreePD.com — site closed notice (verified live): https://freepd.com/
