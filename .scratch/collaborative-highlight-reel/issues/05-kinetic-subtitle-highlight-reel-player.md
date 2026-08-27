# 05: Kinetic Subtitle & Beat-Matched Video Highlight Reel Player

**What to build:**
An interactive Highlight Reel Player executing 60fps kinetic Neo-Brutalist typography (bouncing, shaking, highlighting words), beat-matched media cuts/Ken Burns pan-zooms, lyric-triggered sticker popups, cassette/vinyl reel animation, and full interactive scrub/seek controls.

**Blocked by:** 04: Vocal Song Synthesis & Word-Level SongTimeline Alignment Engine

**Status:** ready-for-agent

- [ ] Kinetic typography `CustomPainter` / render pipeline executing 60fps animations (bounce, shake, burst, karaoke fill).
- [ ] Beat-synced media canvas executing transitions and Ken Burns pan/zoom on musical downbeats.
- [ ] Lyric-triggered evidence sticker popup overlay engine.
- [ ] Interactive playback controls (play, pause, scrub, seek, timecode) maintaining lockstep frame sync.
- [ ] Widget and unit test suite verifying frame calculations at arbitrary millisecond timestamps ($\ge 90\%$ coverage).
