# Song Generation & Word-Level Beat Alignment Engine

`wayfinder:research`

## Question

What is the optimal production architecture for generating high-quality vocal music tracks from lyrics (e.g. ElevenLabs Music API / Suno / custom models) and extracting millisecond-accurate word timestamps and musical beat grids for video synchronization?

## Scope & Deliverables
1. Music generation API evaluation (vocal quality, style adherence, latency, pricing).
2. Word-level forced alignment pipeline (WhisperX / CTC forced aligners / API timestamp responses).
3. Musical beat/onset detection pipeline (librosa / essentia / aubio / audio energy tracker) for tempo and cut point calculation.
