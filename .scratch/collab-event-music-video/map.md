# Map: Collaborative Event Music & Highlight Video Engine

Status: active

## Destination

A decision-complete plan for the Collaborative Event Music & Highlight Video Engine: a web-first collaborative album that turns group photos, clips, and captions into a genre-matched AI vocal track with a lyric-synced highlight reel, ready to hand off for Phase 1 implementation.

## Notes

- Domain: consumer web app (PWA) + AI media pipeline (multimodal LLMs, music synthesis, WhisperX alignment, Remotion rendering).
- Skills to consult: grilling, domain-modeling, research, prototype.
- Standing preferences:
  - Web-first mobile PWA; contributors join without accounts via Magic Link / QR.
  - Free tier is the growth engine; unit economics must stay in the $0.20–$0.32 per-video range.
  - Decisions, not deliverables: this map resolves open choices so a build handoff can proceed.
- Tracker: local markdown under `.scratch/collab-event-music-video/`.

## Decisions so far

<!-- one line per closed ticket, enough to judge relevance, then zoom the link for the detail -->

## Not yet specified

- Exact identity model for organizers vs contributors (does the organizer need an account? email required for magic link?).
- Data model for event spaces, albums, media assets, lyric sheets, and rendered videos.
- What "syllable locking" means technically and how to verify syllable counts in the lyric editor.
- Beat-matched cut / transition algorithm details for the video engine.
- Smart-crop / saliency approach (face detection, subject tracking) and its failure modes.
- Serverless GPU provider and queueing model for WhisperX and Remotion renders.
- Localization / multi-language support for lyrics and UI.
- Moderation, privacy, and takedown handling for user-uploaded media.
- Team/roles and collaboration permissions beyond the organizer.

## Out of scope

- Native iOS/Android apps for v1 (web-first PWA only).
- Full social network / public feed features.
- Contributor accounts as a requirement for joining an event.
- Non-AI/manual video editing tools as the primary experience.
