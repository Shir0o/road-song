# 03: Vocal Song Generation & SongTimeline Beat Alignment

**What to build:** 
The app sends structured lyrics and the selected vibe to the music synthesis service (ElevenLabs Music API / mock fallback) to generate a full vocal song track, then runs forced alignment and onset beat tracking to produce a canonical `SongTimeline` with word-level timestamps and musical beat grids.

**Blocked by:** 02: Trip Narrative Extraction & Rhyming Lyricist Engine

**Status:** ready-for-agent

- [ ] Vocal audio synthesis client supporting vibe selection and audio stream retrieval.
- [ ] Forced alignment and beat/onset detection pipeline extracting millisecond word intervals and downbeats.
- [ ] Canonical `SongTimeline` JSON data structure and serialization.
- [ ] Robust fallback audio generator with mock beat alignment for offline/local use.
- [ ] Test coverage $\ge 90\%$ for audio synthesis and timeline alignment.
