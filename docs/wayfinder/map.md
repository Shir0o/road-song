# Wayfinder Map: Road Song Collaborative Trip Song & Highlight Reel

`wayfinder:map`

## Destination

A complete, production-ready architectural and technical specification (Data Models, Ingestion Pipeline, AI Song Generation, Beat Alignment, Kinetic Subtitle Engine, and Flutter/FFmpeg Video Compilation) ready for immediate phased implementation.

## Notes

- Domain glossary defined in [CONTEXT.md](../../CONTEXT.md).
- Skills: `grilling`, `domain-modeling`, `research`, `prototype`.
- Visual Aesthetic: Neo-Brutalist (high contrast, hard shadows, sticker/polaroid tape accents, dynamic kinetic typography).
- Technology Stack: Flutter (Client/Player/Export), Cloud AI (Gemini 2.0 / ElevenLabs / Suno / WhisperX / Forced Aligner), Firestore & Cloud Storage (Session media sync).

## Decisions so far

<!-- the index: one line per closed ticket, enough to judge relevance, then zoom the link for the detail the ticket holds -->

## Tickets

### Frontier (Open & Unblocked)

- [Collaborative Session Ingestion & Guest Drop Architecture](tickets/ticket-01-session-ingestion.md) (`wayfinder:research`)
- [Multimodal Trip Narrative Extraction & Rhyming Lyricist Schema](tickets/ticket-02-narrative-lyricist-schema.md) (`wayfinder:research`)
- [Song Generation & Word-Level Beat Alignment Engine](tickets/ticket-03-song-gen-alignment.md) (`wayfinder:research`)

### Blocked

- [SongTimeline Data Model & Kinetic Subtitle Rendering Engine](tickets/ticket-04-kinetic-subtitle-engine.md) (`wayfinder:prototype`) — *Blocked by [Multimodal Trip Narrative Extraction & Rhyming Lyricist Schema](tickets/ticket-02-narrative-lyricist-schema.md), [Song Generation & Word-Level Beat Alignment Engine](tickets/ticket-03-song-gen-alignment.md)*
- [Beat-Matched Highlight Reel Assembly & FFmpeg Export Pipeline](tickets/ticket-05-highlight-reel-export.md) (`wayfinder:research`) — *Blocked by [Collaborative Session Ingestion & Guest Drop Architecture](tickets/ticket-01-session-ingestion.md), [SongTimeline Data Model & Kinetic Subtitle Rendering Engine](tickets/ticket-04-kinetic-subtitle-engine.md)*
- [End-to-End System Blueprint & Phased Execution Plan](tickets/ticket-06-system-blueprint.md) (`wayfinder:task`) — *Blocked by all previous tickets*

## Not yet specified

- Native iOS/Android hardware-accelerated video rendering vs. flutter_ffmpeg bundle size tradeoffs.
- Dynamic sticker/evidence overlays triggered by lyric keywords (e.g. popping a receipt image when "expensive tacos" is sung).
- Offline-first caching for road trip areas with zero cellular connectivity.

## Out of scope

- Real-time live audio recording of multi-track instruments by users in the app.
- Full manual multi-track DAW timeline editing (we are zero-friction automated compilation).
- Paid streaming service direct distribution (Spotify / Apple Music upload).
