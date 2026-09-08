import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_song/models/song_models.dart';
import 'package:road_song/models/trip_models.dart';
import 'package:road_song/services/share_memorial_service.dart';

void main() {
  group('ShareMemorialService Tests', () {
    const service = ShareMemorialService();

    test('slugify converts special characters and preserves readability', () {
      expect(service.slugify("Cabo Fail '23!"), 'cabo-fail-23');
      expect(service.slugify('Highway Sunrise (Pop-Punk)'), 'highway-sunrise-pop-punk');
      expect(service.slugify('---'), 'memorial');
    });

    test('buildShareLink constructs clean tokenized URL', () {
      final link = service.buildShareLink(
        tripName: "Cabo Fail '23",
        songTitle: 'Lost Shoes',
      );
      expect(link, 'https://roadsong.app/m/cabo-fail-23-lost-shoes');
    });

    test('generatePreviewMetadata creates valid web card metadata and HTML tags', () {
      final timeline = SongTimeline(
        schemaVersion: 1,
        title: 'Lost Shoes',
        styleId: 'pop-punk',
        bpm: 168,
        durationMs: 75000,
        downbeat: const DownbeatGrid(
          beatIntervalMs: 357.14,
          beatsPerBar: 4,
          offsetMs: 0,
          durationMs: 75000,
        ),
        sections: const [],
        cues: const [],
      );

      final memories = [
        const TimelineMemory(
          id: 'mem-1',
          author: 'Maya',
          time: '12:00',
          text: 'Lost our flip flops in the surf',
          imageUrl: 'https://roadsong.app/photos/beach.jpg',
        ),
      ];

      final crew = [
        const CrewMember(
          id: 'maya',
          name: 'Maya Chen',
          handle: '@maya',
          initial: 'M',
          color: Color(0xFF7D8663),
        ),
      ];

      final meta = service.generatePreviewMetadata(
        tripName: 'Baja 2024',
        timeline: timeline,
        memories: memories,
        crew: crew,
      );

      expect(meta.title, 'Lost Shoes (Baja 2024)');
      expect(meta.imageUrl, 'https://roadsong.app/photos/beach.jpg');
      expect(meta.audioDurationFormatted, '1:15');
      expect(meta.vibeLabel, 'POP-PUNK');
      expect(meta.participantNames, contains('Maya Chen'));

      final html = meta.toHtmlMetaTags();
      expect(html, contains('og:title'));
      expect(html, contains('Lost Shoes'));
      expect(html, contains('twitter:card'));
    });
  });
}
