# Collaborative Trip Song & Beat-Synced Highlight Reel Engine

`status:ready-for-agent`

## Problem Statement

Friends and families capture hundreds of photos and videos during road trips, getaways, and celebrations. These assets languish in camera rolls because manual video editing, music synchronization, and captioning require significant time and specialized skills. Furthermore, trip memories lack a cohesive, celebratory narrative artifact that captures the inside jokes and unique energy of the group.

## Solution

A zero-friction collaborative album where trip participants contribute photos, videos, and funny text moments without account friction. The engine extracts the trip narrative, writes custom rhyming lyrics, generates a full vocal song track, and compiles an automated highlight reel with beat-matched cuts and kinetic karaoke subtitles.

## User Stories

1. As a trip host, I want to create a collaborative Session in seconds and generate a shareable QR code / invite link, so that everyone in the car or group can immediately contribute.
2. As a trip participant, I want to join a Session via invite link without creating an account or downloading a heavy app, so that there is zero barrier to sharing my photos and clips.
3. As a trip participant, I want to upload high-resolution photos and video snippets from my camera roll, so that our shared album contains all angles of the trip.
4. As a trip participant, I want to type in funny quotes, inside jokes, and weird moments (e.g., "Dave ordered 14 tacos at 3 AM"), so that our shared lore is captured.
5. As a trip participant, I want to scan or photograph receipts, tickets, and souvenir labels as evidence, so that our trip scrapbook has authentic physical artifacts.
6. As a trip host, I want to select a musical vibe (Pop-Punk, Euro-Trash Synth, Sad Boy Indie, Chaotic Rap, etc.) and song duration, so that the generated track matches our trip's mood.
7. As a trip host, I want the AI engine to analyze all uploaded media and text evidence to extract a coherent narrative arc (Intro $\rightarrow$ Rising Chaos $\rightarrow$ Chorus Climax $\rightarrow$ Outro), so that the song tells a real story rather than generic trivia.
8. As a trip host, I want the AI lyricist to write structured, witty rhyming verses and choruses that explicitly name-drop trip participants and their funny moments.
9. As a trip host, I want the system to generate a full vocal song track based on the custom lyrics and chosen vibe.
10. As a trip participant, I want to see the lyrics synchronized with millisecond accuracy to the singing vocal track, so that we can follow along like dynamic karaoke.
11. As a trip participant, I want kinetic subtitles that bounce, scale, shake, and change colors in sync with vocal beats and syllable timing over our footage.
12. As a trip participant, I want the video reel to automatically cut, transition, and pan/zoom photos exactly on musical beats and downbeats.
13. As a trip host, I want to preview the kinetic video and song interactively in real time with play, pause, scrub, and seek controls.
14. As a trip host, I want to export the final highlight reel as a high-definition 1080p MP4 video with baked-in kinetic subtitles and synchronized audio, so that I can easily share it on Instagram, TikTok, YouTube, or group chats.
15. As a trip participant, I want to revisit saved road trip song albums offline in the app scrapbook anytime.

## Implementation Decisions

### Architectural Seams
The feature is split across four high-level architectural boundaries:

1. **Session & Media Ingestion Seam**
   - Cloud session store (Firestore & Cloud Storage) managing session lifecycle, media blobs, thumbnailing, and evidence metadata.
   - Zero-friction guest contribution via tokenized session links/QR codes.
   - Pre-processing pipeline that extracts EXIF timestamps, media duration, visual highlights, and text anecdotes.

2. **Narrative Extraction & Rhyming Lyricist Seam**
   - Multimodal clustering algorithm that groups media and text notes into chronological trip chapters.
   - LLM prompt orchestration (Gemini Multimodal) returning structured JSON lyrics formatted into standard musical sections (`[Intro]`, `[Verse 1]`, `[Chorus]`, `[Verse 2]`, `[Bridge]`, `[Outro]`), rhyming structures, syllable constraints, and explicit participant references.

3. **Song Synthesis & Word-Level Beat Alignment Seam**
   - Audio synthesis engine (ElevenLabs Music API / Suno integration) generating full vocal tracks.
   - Audio-to-text forced alignment (WhisperX / CTC aligner) and onset beat tracking to produce a canonical `SongTimeline`.
   - The `SongTimeline` data contract maps downbeats, tempo/BPM, section markers, and word/syllable-level millisecond intervals with visual kinetic animation tags (`bounce`, `shake`, `highlight`, `burst`).

4. **Kinetic Subtitle & Highlight Reel Compilation Seam**
   - Real-time interactive Flutter canvas engine (`CustomPainter` / render pipeline) executing 60fps kinetic Neo-Brutalist typography and beat-synced photo/clip switching.
   - Video assembly pipeline utilizing an FFmpeg filtergraph to produce a high-bitrate 1080p MP4 combining video clips, Ken Burns animated photos, audio track, and kinetic subtitle overlays.

### Visual Language & Theme
- Strict adherence to Neo-Brutalist aesthetics (`BrutalTheme`): heavy offset drop shadows, thick ink-black borders, high-contrast flat colors (yellow, cyan, lime, primary pink), distressed paper textures (`GrainOverlay`), and rotated sticker badges.

## Testing Decisions

### Test Strategy & External Behavior
- Focus strictly on high-level boundary tests and observable output contracts rather than internal state variables or transient widgets.
- The primary test seam is the service layer and timeline parser/compiler:
  - Verifying session contribution ingestion contracts and metadata preservation.
  - Verifying lyricist schema validation (ensuring required section keys, non-empty verses, and valid syllable arrays).
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
