# SongTimeline Data Model & Kinetic Subtitle Rendering Engine

`wayfinder:prototype`

## Question

How should the `SongTimeline` JSON specification be designed, and how should the Flutter client render high-performance, 60fps kinetic Neo-Brutalist subtitles (bouncing words, karaoke fills, shake effects, sticker popups) synchronized to audio playback?

## Scope & Deliverables
1. Canonical `SongTimeline` JSON schema (sections, lines, words, syllable intervals, visual effect triggers).
2. Flutter CustomPainter / AnimatedWidget kinetic typography prototype.
3. Interactive karaoke player with scrub, seek, and real-time audio sync.
