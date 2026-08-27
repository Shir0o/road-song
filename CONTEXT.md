# CONTEXT.md

Domain terminology and glossary for Road Song.

## Core Concepts

### Session
A shared trip container where participants gather photos, videos, audio notes, and text snippets ("evidence") from a trip, getaway, or celebration. Identified by a shareable code / deep link.

### Evidence
A contributed multimodal asset within a Session.
- **Media Evidence**: Photos, video clips, bursts, or panoramas with EXIF timestamps and optional location metadata.
- **Lore / Moment Evidence**: Short text quotes, inside jokes, embarrassing moments, typewriter notes, or receipt scans.

### Trip Narrative
The structured story extracted from all contributed Evidence in a Session, chronologically grouped into thematic highlights (e.g., "The Flat Tire Incident", "Sunset Taco Run").

### Song Generation Engine
The service responsible for turning the Trip Narrative into a full vocal song track:
- **Lyricist (LLM)**: Generates rhyming verses, choruses, and bridges referencing participants and trip moments.
- **Vocal/Music Synthesizer**: Produces full-fidelity vocal audio matching the chosen vibe (e.g., Pop-Punk, Indie, Synthwave).
- **Timeline Aligner**: Produces millisecond-accurate word-level and beat-level sync metadata (`SongTimeline`).

### SongTimeline
A structured JSON schema mapping beats, downbeats, musical sections (intro, verse, chorus, drop, outro), and word-level kinetic timestamp markers for synchronization.

### Kinetic Subtitles
Animated on-screen typography that scales, bounces, shakes, and highlights in exact sync with vocal syllables and musical accents.

### Highlight Reel
The compiled automated video syncing media clips with the generated song:
- **Beat-Matched Cuts**: Transitions and image pan/zoom cuts occurring on musical beats/downbeats.
- **Kinetic Karaoke Layer**: Real-time canvas overlay rendering kinetic lyrics over the footage.
- **Renderer / Exporter**: Client-side interactive Flutter preview player and background FFmpeg export pipeline delivering an MP4.
