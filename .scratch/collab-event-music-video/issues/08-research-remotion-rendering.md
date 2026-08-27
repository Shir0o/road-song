# 08: Choose the Remotion rendering architecture

Type: research
Status: open
Blocked by: 01

## Question

How should the programmatic highlight video be rendered with Remotion on AWS Lambda?

Research and decide:
- Lambda rendering setup, concurrency, and cost for 1080p/4K exports.
- Asset packaging and media upload flow (R2 / S3).
- Smart crops / saliency cropping and beat-matched photo transitions.
- Kinetic lyric subtitle rendering from WhisperX timestamps.
- Queueing and retry strategy for long renders.

## Notes

- The brief calls for 1080p/4K programmatic highlight reels with kinetic lyric typography.
- Depends on the chosen music API (01) because the master track drives sync and timing.
