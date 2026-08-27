# Beat-Matched Highlight Reel Assembly & FFmpeg Export Pipeline

`wayfinder:research`

## Question

How should video clips, Polaroid photos, and kinetic subtitles be automatically cut on musical beats and rendered into an exportable, shareable 1080p MP4 highlight reel on device or via background worker?

## Scope & Deliverables
1. Beat-matching cut algorithm (pairing high-energy chorus drops with key photo/video highlights, Ken Burns pan/zoom on photos).
2. Video rendering pipeline (Flutter canvas frame capture vs. FFmpeg complex filtergraph / native platform encoders).
3. Export performance, resolution targets, and memory optimization on mobile devices.
