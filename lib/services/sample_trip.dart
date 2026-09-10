import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/song_models.dart';
import '../models/trip_models.dart';

/// 1x1 transparent PNG — a decodable photo fixture for the sample trip's
/// photo memory (no network, no asset dependency).
const List<int> _samplePhotoPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

/// The first-launch sample trip (issue #31): a fully populated memorial that
/// demonstrates the whole arc — multiple contributors, mixed media, pinned
/// places along a route, and a finished song (lyrics + vibe + audio + ready
/// state) — so a demo never looks empty. Loading it goes through the
/// [TripStore] seam like any other trip; the sample then flows through the
/// real screens (diary, route, lyrics, Making Song, player, share) with no
/// special-casing.
Trip buildSampleTrip() {
  final Uint8List photoBytes = Uint8List.fromList(_samplePhotoPng);
  final Uint8List videoBytes = Uint8List.fromList(List.filled(4096, 7));
  return Trip(
    id: 'sample-trip',
    name: 'Lisbon → Porto',
    firstDay: 'JUN 12',
    lastDay: 'JUN 18',
    coverIndex: 2,
    crew: const [
      CrewMember(
        id: 'maya',
        name: 'Maya Chen',
        handle: '@maya',
        initial: 'M',
        color: Color(0xFF7D8663),
        invited: true,
      ),
      CrewMember(
        id: 'tom',
        name: 'Tom Alvarez',
        handle: '@tomtom',
        initial: 'T',
        color: Color(0xFFB08A3E),
        invited: true,
      ),
      CrewMember(
        id: 'priya',
        name: 'Priya Nair',
        handle: '@priya.n',
        initial: 'P',
        color: Color(0xFF3E6B8A),
        invited: true,
      ),
    ],
    sessionLink: 'roadsong.app/t/lisbon-porto',
    createdAt: DateTime(2026, 6, 12),
    memories: [
      TimelineMemory(
        id: 'sample-photo',
        author: '@maya',
        contributor: 'Maya',
        time: '10:12 AM',
        text: 'Tram 28, all five of us. The driver gave up on the route.',
        day: 1,
        dayDate: 'JUN 12',
        locationName: 'Alfama, Lisbon',
        latitude: 38.712,
        longitude: -9.131,
        caption: 'tram 28, all five of us',
        type: MemoryType.photo,
        photoBytes: photoBytes,
        rotationDegrees: -2.0,
      ),
      TimelineMemory(
        id: 'sample-text-1',
        author: '@tomtom',
        contributor: 'Tom',
        time: '02:15 PM',
        text: 'The wrong hill, Sintra. Never again.',
        day: 1,
        dayDate: 'JUN 12',
        locationName: 'Sintra, the wrong hill',
        latitude: 38.794,
        longitude: -9.388,
        rotationDegrees: 1.5,
      ),
      TimelineMemory(
        id: 'sample-video',
        author: '@priya.n',
        contributor: 'Priya',
        time: '11:40 PM',
        text: 'Karaoke meltdown. We owe the owner an apology.',
        day: 2,
        dayDate: 'JUN 13',
        locationName: 'Karaoke Den, Porto',
        latitude: 41.1496,
        longitude: -8.6109,
        caption: 'mr. brightside, destroyed',
        type: MemoryType.video,
        videoBytes: videoBytes,
        rotationDegrees: 3.0,
      ),
      TimelineMemory(
        id: 'sample-text-2',
        author: '@you',
        contributor: 'You',
        time: '09:00 AM',
        text: 'Pastéis de nata count: 19. Not sorry.',
        day: 2,
        dayDate: 'JUN 13',
        rotationDegrees: -1.0,
      ),
    ],
    song: const LyricSong(
      title: 'Every Wrong Turn',
      sections: [
        LyricSection(
          id: 'intro',
          label: 'Intro',
          variants: [
            [
              'Lisbon → Porto, as told by Maya, Tom and Priya,',
              'scrapbook open, tape rolling —',
              'every wrong turn, kept forever.',
            ],
            [
              'Press play on Lisbon → Porto:',
              'the notes are messy, the company is good,',
              "this one's for the group chat.",
            ],
          ],
        ),
        LyricSection(
          id: 'v1',
          label: 'Verse 1',
          variants: [
            [
              'It started in Alfama, Lisbon,',
              'Tram 28, all five of us,',
              'Maya swears it went differently —',
              'The tape says otherwise, friend.',
            ],
            [
              'Day one, Alfama, Lisbon. The plan:',
              'We followed the loudest opinion,',
              'And Maya led us confidently the wrong way —',
              'Honestly? A strong start.',
            ],
          ],
        ),
        LyricSection(
          id: 'ch',
          label: 'Chorus',
          variants: [
            [
              'Sing it back on the long road through Lisbon → Porto,',
              'every wrong turn worth the detour,',
              'from Alfama, Lisbon to Karaoke Den, Porto, we held the line,',
              "this one's ours forevermore.",
            ],
            [
              'Sing it louder on the road through Lisbon → Porto,',
              'GPS crying "please turn around" —',
              'from Alfama, Lisbon to Karaoke Den, Porto we got lost,',
              'but look what we found.',
            ],
          ],
        ),
        LyricSection(
          id: 'v2',
          label: 'Verse 2',
          variants: [
            [
              'By mid-trip the lore was thickening:',
              'The wrong hill, Sintra. Never again.,',
              "And Tom said it couldn't get worse —",
              'It got worse. We have photos.',
            ],
            [
              'Somewhere around the halfway mark,',
              'The snacks ran out, the stories did not,',
              "We swore we'd do better tomorrow —",
              'We did not. Iconic.',
            ],
          ],
        ),
        LyricSection(
          id: 'br',
          label: 'Bridge',
          variants: [
            [
              'And then — Pastéis de nata count: 19. Not sorry. —',
              'nobody said much at all,',
              'Priya broke the silence:',
              '"...yeah." Some things don\'t need words.',
            ],
            [
              'The loudest day ended in quiet,',
              'we let the silence hold it,',
              'Priya tried to take a photo,',
              'Some moments refuse to fit the frame.',
            ],
          ],
        ),
        LyricSection(
          id: 'out',
          label: 'Outro',
          variants: [
            [
              "So here's to Lisbon → Porto,",
              'to Maya, Tom and Priya,',
              'press play, and remember it all —',
              'every wrong turn, kept forever.',
            ],
            [
              'One last chorus for the road,',
              'for Maya, Tom and Priya and the ones who missed it,',
              "Lisbon → Porto, we'll be back for you —",
              'till then, the tape keeps rolling.',
            ],
          ],
        ),
      ],
    ),
    songArtifact: const SongArtifact(
      styleId: 'pop-punk',
      audioAsset: 'audio/vibes/pop_punk.mp3',
      bpm: 168,
      stageIndex: 4,
    ),
  );
}
