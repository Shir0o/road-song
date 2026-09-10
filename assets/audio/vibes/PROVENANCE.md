# Vibe audition audio — provenance manifest

These five MP3 files are the bundled vibe-audition audio for the Choose
Sound stage (issue #29). They are **synthesized in-repo placeholders**:
generated from scratch by this repository's own script, with no samples,
no third-party recordings, and no network access.

| File | Vibe | Tempo | Key | Timbre |
|---|---|---|---|---|
| `pop_punk.mp3` | Pop-Punk | 168 BPM | A | square lead + square bass + kick |
| `euro_trash_synth.mp3` | Euro-Trash Synth | 128 BPM | F | saw lead + saw bass + kick + hats |
| `sad_boy_indie.mp3` | Sad Boy Indie | 92 BPM | E | triangle lead + sine bass |
| `acoustic_road_folk.mp3` | Acoustic Road Folk | 104 BPM | G | triangle lead + sine bass |
| `chaotic_rap.mp3` | Chaotic Rap | 144 BPM | D | saw lead + square bass + kick + hats |

## License

CC0-equivalent by construction: the audio is the deterministic output of
`tool/generate_vibe_audio.py` (committed in this repo), which renders
simple oscillator loops (sine/square/saw/triangle) with no copyrighted
material. Anyone may use, modify, and redistribute it without attribution.

## Regeneration

```sh
python3 tool/generate_vibe_audio.py   # requires Python 3 + ffmpeg on PATH
```

Each run is deterministic (fixed random seed), so the committed files are
reproducible byte-for-byte.

## Swap-in path

When licensed production tracks are available, replace each MP3 with the
licensed file (same filename, MP3 @96–128 kbps, ~8 s or longer — the
audition plays the asset as-is), update this manifest with the per-track
source URL, download date, license name + URL, and author, and re-run the
tests. No code changes are needed: the vibe → asset mapping lives in
`MusicalStyle.audioAsset` (`lib/models/song_models.dart`).
