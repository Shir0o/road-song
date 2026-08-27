# Collaborative Trip Scrapbook, AI Song Generator & Beat-Synced Video Highlight Reel

`status:ready-for-agent`

## Problem Statement

Trip participants and family groups take hundreds of photos, videos, and capture funny inside jokes during road trips and holidays. These moments remain trapped in disorganized camera rolls because manual video editing, musical soundtrack matching, rhyming lyric writing, and kinetic subtitle synchronization require excessive time and specialized video production skills. Furthermore, trip memories lack an authentic, celebratory keepsake—an artifact that blends the nostalgic tactile charm of a physical travel zine/scrapbook with the dynamic entertainment of a custom-generated theme song and highlight reel.

## Solution

A zero-friction, tactile collaborative trip app (combining warm editorial riso zine aesthetics with Neo-Brutalist accents) where trip participants contribute photos, short video clips, funny quotes, and physical evidence (receipts, tickets) via QR codes and deep links without requiring app installs or account sign-ups.

The app organizes these moments into a shared chronological **Trip Diary**, visualizes milestones along a **Trip Route Map**, extracts the trip narrative into structured rhyming lyrics with conversational AI refinement, synthesizes a full vocal theme song in a chosen genre, and generates a **Beat-Synced Video Highlight Reel & Memorial Keepsake** featuring millisecond-accurate kinetic karaoke subtitles, beat-matched photo/clip cuts, contextual sticker popups, and full 1080p MP4 social export.

## User Stories

### Session Setup, Onboarding & Collaborative Ingestion
1. As a trip creator, I want to see an inspiring welcome onboarding screen with tactile scrapbook polaroids, so that I understand the concept of turning our shared trip into a song.
2. As a trip creator, I want to create a new trip by entering the trip title (e.g. "Lisbon → Porto"), date range, and picking a tactile zine/scrapbook cover pattern, so that our session has a distinct visual personality.
3. As a trip host, I want to invite trip friends from my contact list or share a short invite link / QR code (`roadsong.app/t/...`), so that everyone in the car can immediately join the session without account creation or mandatory app downloads.
4. As a guest trip participant, I want to open the shared session via mobile web or app and drop photos, video clips, and voice memos directly into the shared trip pool with preserved EXIF timestamps.
5. As a trip participant, I want to add text memories, funny quotes, and inside jokes via a quick-access "+ Add Memory" sheet, tagging the location milestone and attaching photos.
6. As a trip participant, I want to react to ("♥ Like") memories and moments in the shared diary feed, so that the group can vote on the funniest highlights.

### Trip Diary & Route Map Experience
7. As a trip participant, I want to browse our chronological day-by-day **Diary Feed** with polaroid-style photos, washi tape accents, and author badges.
8. As a trip participant, I want to switch to the **Route Map Tab** to view an illustrated map showing all trip stops, route pins, total kilometers traveled, and per-stop memory counts.
9. As a trip participant, I want to tap any stop pin or milestone card on the route map to jump directly to the memories captured at that location.

### AI Narrative Extraction & Conversational Lyricist
10. As a trip host, I want the AI engine to read all contributed text moments, photo descriptions, and receipt scans to automatically extract a 4-act narrative arc (Intro $\to$ Rising Chaos $\to$ Chorus Climax $\to$ Outro).
11. As a trip host, I want the AI lyricist to structure generated song lyrics into modular musical sections (`[Intro]`, `[Verse 1]`, `[Chorus]`, `[Verse 2]`, `[Bridge]`, `[Outro]`) that name-drop trip participants and their specific funny quotes.
12. As a trip host, I want to inspect lyrics section-by-section with the ability to click `↻ rewrite` on an individual section or manually edit lines with `✎ edit`.
13. As a trip host, I want a persistent natural-language chat prompt at the bottom of the lyrics view (e.g., *"Make the chorus punchier and mention the warm milk incident"*) to interactively refine the lyrics in conversational dialogue with the AI.

### Song Synthesis & Vibe Selection
14. As a trip host, I want to choose the musical vibe and tempo for our song (e.g., "Pop-Punk 2000s", "Euro-Trash Synth", "Sad Boy Indie", "Acoustic Road Folk", "Chaotic Rap") before generating the audio.
15. As a trip participant, I want to hear a studio-quality vocal track generated from our customized lyrics matching our selected genre and tempo.
16. As a trip participant, I want the system to compute millisecond-accurate word-level and syllable-level alignments (`SongTimeline`) mapped to downbeats and tempo changes.

### Kinetic Subtitle & Beat-Matched Video Highlight Reel
17. As a trip participant, I want to watch an interactive **Highlight Reel Player** where kinetic typography bounces, shakes, scales, and highlights in exact synchrony with the singing vocals over our photos and video footage.
18. As a trip participant, I want photos and video clips to automatically cut, transition, and execute Ken Burns pan/zoom effects strictly on musical downbeats and rhythmic accents.
19. As a trip participant, I want key evidence artifacts (e.g., receipt photos, tickets, map stamps) to trigger as dynamic pop-up stickers on screen at the exact moment their corresponding lyric is sung.
20. As a trip host, I want full interactive playback controls (play, pause, scrub, seek) that keep audio, video cuts, and kinetic typography in 60fps frame-accurate lockstep.

### Memorial Keepsake & High-Definition Video Export
21. As a trip participant, I want to view and share a **Tactile Memorial Card** featuring our scrapbook cover, tape mounts, participant avatar stack, and one-tap audio/video playback.
22. As a trip host, I want to export the finished highlight reel as a high-definition 1080p MP4 video (in 9:16 vertical and 16:9 widescreen formats) with baked-in kinetic typography and audio, suitable for sharing directly on Instagram Reels, TikTok, YouTube Shorts, or group chats.
23. As a trip participant, I want to copy a public share link so friends and family can view the memorial and stream the song online.

## Implementation Decisions

### Architectural Seams & 3-Tab Scrapbook Shell
The system unifies the design reference prototype with the backend media and AI engine across the following core boundaries:

1. **Client Shell & 3-Tab Navigation Seam**
   - **Onboarding Flow**: `WelcomeScreen` (editorial hero & polaroids), `CreateTripScreen` (trip title, dates, cover picker), and `InviteCrewScreen` (friend checklist, tokenized link & QR drop portal).
   - **3-Tab Experience**:
     - **Diary Tab**: Chronological feed of memories, polaroid cards with washi tape/rotation, like buttons, and floating `+` composer sheet with location pinning.
     - **Route Tab**: Interactive route map canvas, milestone stop cards, and distance odometer.
     - **Song Tab**: State machine spanning narrative extraction, section-by-section lyricist with conversational chat feedback, vibe selector, audio cassette / highlight reel player, and shareable memorial card.

2. **Session & Media Ingestion Seam**
   - Cloud session store (Firestore & Cloud Storage) managing session lifecycle, media blobs, thumbnailing, and evidence metadata.
   - Zero-friction guest contribution via tokenized session links/QR codes without mandatory user auth.
   - Pre-processing pipeline that extracts EXIF timestamps, media duration, visual highlights, and text anecdotes.

3. **Narrative Extraction & Rhyming Lyricist Seam**
   - Multimodal clustering algorithm that groups media and text notes into chronological trip chapters.
   - LLM prompt orchestration returning structured JSON lyrics formatted into musical sections (`[Intro]`, `[Verse 1]`, `[Chorus]`, `[Verse 2]`, `[Bridge]`, `[Outro]`), rhyming structures, syllable constraints, and explicit participant references with real-time chat refinement capabilities.

4. **Song Synthesis & `SongTimeline` Alignment Seam**
   - Audio synthesis engine (ElevenLabs Music API / Suno integration) generating vocal tracks across selected genres.
   - Audio-to-text forced alignment (WhisperX / CTC aligner) and onset beat tracking producing a canonical `SongTimeline`.
   - The `SongTimeline` data contract maps downbeats, tempo/BPM, section markers, and word/syllable-level millisecond intervals with visual kinetic animation tags (`bounce`, `shake`, `highlight`, `burst`) and timed evidence sticker popups.

5. **Kinetic Subtitle & Highlight Reel Compilation Seam**
   - Real-time interactive Flutter canvas engine executing 60fps kinetic typography, sticker popups, and beat-synced photo/clip switching.
   - Video assembly pipeline utilizing an FFmpeg filtergraph to produce a high-bitrate 1080p MP4 combining video clips, Ken Burns animated photos, audio track, and kinetic subtitle overlays.

### Visual Language & Aesthetic
- Warm tactile travel zine meets Neo-Brutalist accents: warm paper cream (`#F8F2E4`), secondary parchment (`#F1E7D1`), card white (`#FFFDF4`), dark ink brown (`#443729`), muted earth (`#8D7C63`), accent terracotta brick red (`#C05B3E`) or riso orange (`#FF5B22`), and riso cobalt ink (`#1E45C0`).
- Tactile details: tape strips with multiply blend mode, subtle paper grain texture overlay, tilted polaroid borders ($-3^\circ$ to $+3^\circ$), dashed stitch borders, and retro cassette spool animation.

## Testing Decisions

### Test Strategy & External Behavior
- Focus strictly on high-level boundary tests and observable output contracts rather than internal state variables or transient widgets.
- The primary test seam is the service layer and timeline parser/compiler:
  - Verifying session contribution ingestion contracts and metadata preservation.
  - Verifying lyricist schema validation (ensuring required section keys, non-empty verses, and valid syllable arrays).
  - Verifying conversational chat lyric refinement transforms.
  - Verifying `SongTimeline` parser behavior given simulated audio alignment timestamps.
  - Verifying kinetic subtitle frame calculation logic given specific playback timestamps.
  - Verifying video composition recipe generation for FFmpeg command-line builders.
- Widget tests for the interactive player ensuring seek, scrub, play, and pause events properly synchronize the active lyric line and media index.
- Adhere to the repository standard of **$\ge 90\%$ test coverage** on new components.

## Out of Scope

- Real-time live multi-track instrument recording or direct DAW editing.
- Manual non-linear video editing timeline (e.g. keyframing audio curves or manual multi-layer video tracks).
- Direct automated publishing to third-party streaming platforms (Spotify, Apple Music).
- Complex facial recognition clustering (relying instead on timestamps, captions, and user tagging).

## Further Notes

- In low-connectivity environments (remote road trips), media and evidence are cached locally and synced automatically once connection is re-established.
- The pipeline architecture cleanly isolates the music generation API, allowing seamless swapping of backend providers (e.g., ElevenLabs $\leftrightarrow$ Suno $\leftrightarrow$ local open-source models) without modifying the downstream kinetic player or video export pipeline.

