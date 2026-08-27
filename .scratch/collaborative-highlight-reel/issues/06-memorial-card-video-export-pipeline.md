# 06: Tactile Memorial Card & 1080p MP4 Video Highlight Reel Export

**What to build:**
The final `Share Memorial` view featuring the tape-mounted keepsake card with avatar stacks and copy link action, plus the FFmpeg/native video composition pipeline exporting high-bitrate 1080p MP4s (in 9:16 vertical and 16:9 widescreen formats) for social sharing.

**Blocked by:** 05: Kinetic Subtitle & Beat-Matched Video Highlight Reel Player

**Status:** ready-for-agent

- [ ] Tactile `ShareMemorialScreen` card with scrapbook cover styling, tape mounts, and participant avatars.
- [ ] Shareable link generator and preview web card metadata.
- [ ] FFmpeg filtergraph recipe builder translating `SongTimeline` and media into 1080p MP4 with baked subtitles and audio.
- [ ] Aspect ratio presets (9:16 vertical for TikTok/Reels and 16:9 widescreen).
- [ ] Unit tests for FFmpeg command generation and export lifecycle state machine ($\ge 90\%$ coverage).
