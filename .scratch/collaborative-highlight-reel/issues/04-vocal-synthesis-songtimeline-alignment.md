# 04: Vocal Song Synthesis & Word-Level SongTimeline Alignment Engine

**What to build:**
The Vibe/Style selection cards (Pop-Punk, Euro-Trash Synth, Sad Boy Indie, Acoustic Road Folk, Chaotic Rap, etc.), a vocal music synthesis pipeline connecting finalized lyrics to audio generation (ElevenLabs/Suno), and audio-to-text forced alignment producing a canonical `SongTimeline` with millisecond-accurate word/syllable timestamps, downbeat grids, and evidence sticker cues.

**Blocked by:** 03: Modular Lyricist Engine with Section Rewriter & Conversational AI Chat

**Status:** ready-for-agent

- [ ] Musical style & tempo picker screen with preview metadata cards.
- [ ] Vocal song synthesis service producing high-quality vocal audio tracks from structured lyrics.
- [ ] Forced alignment engine generating canonical `SongTimeline` JSON with word/syllable timestamps and downbeat grid.
- [ ] Evidence cue generator mapping lyric keywords to trip photo/sticker popup timestamps.
- [ ] Unit tests validating `SongTimeline` parser and audio alignment data contracts ($\ge 90\%$ coverage).
