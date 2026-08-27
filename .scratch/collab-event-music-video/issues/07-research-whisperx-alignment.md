# 07: Choose WhisperX alignment deployment

Type: research
Status: open
Blocked by: 01

## Question

How should WhisperX word-level timestamping be deployed for the audio-to-lyric alignment stage?

Research and decide:
- Serverless GPU options (e.g., RunPod, Modal, Replicate, AWS Lambda GPU) and their cost/latency.
- Expected accuracy for sung vocals with music.
- Input/output format and how timestamps flow into Remotion subtitles.
- Fallback behavior when alignment confidence is low.

## Notes

- The brief estimates $0.03–$0.05 for WhisperX timestamping + Remotion render.
- Depends on the chosen music API (01) since alignment runs on the generated master track.
