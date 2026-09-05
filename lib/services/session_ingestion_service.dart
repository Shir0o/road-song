import '../models/trip_models.dart';

/// Service responsible for creating session links and parsing guest drops
/// (photos, video clips, and text quotes) with preserved capture timestamps.
class SessionIngestionService {
  const SessionIngestionService();

  /// Converts a trip name into a URL-safe session slug.
  String slugify(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'trip' : cleaned;
  }

  /// Builds a tokenized session link for a trip.
  String buildSessionLink(String tripName) {
    return 'roadsong.app/t/${slugify(tripName)}';
  }

  /// Creates a text quote drop.
  GuestDrop createTextDrop({
    required String author,
    required String text,
    DateTime? timestamp,
    String? location,
  }) {
    return GuestDrop(
      type: GuestDropType.text,
      author: author,
      content: text,
      capturedAt: timestamp ?? DateTime.now(),
      location: location,
    );
  }

  /// Parses a media (photo/video) drop from raw bytes.
  ///
  /// For photos, a JPEG EXIF `DateTimeOriginal` tag is used when present.
  /// Videos and photos without EXIF fall back to [fallbackTimestamp].
  GuestDrop parseMediaDrop({
    required List<int> bytes,
    required String author,
    required String filePath,
    required GuestDropType type,
    DateTime? fallbackTimestamp,
    String? location,
  }) {
    DateTime? capturedAt = fallbackTimestamp ?? DateTime.now();
    if (type == GuestDropType.photo) {
      final exif = extractExifDateTime(bytes);
      if (exif != null) {
        capturedAt = exif;
      }
    }
    return GuestDrop(
      type: type,
      author: author,
      content: filePath,
      capturedAt: capturedAt,
      location: location,
    );
  }

  /// Extracts the EXIF `DateTimeOriginal` from JPEG bytes, if present.
  ///
  /// Returns `null` when the bytes are not a JPEG with a readable EXIF tag.
  DateTime? extractExifDateTime(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return null;
    }

    int offset = 2;
    while (offset < bytes.length - 1) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      final int marker = bytes[offset + 1];

      // Standalone markers have no length field.
      if (marker == 0xD8 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        offset += 2;
        continue;
      }

      if (offset + 4 > bytes.length) {
        break;
      }

      final int segmentLength = (bytes[offset + 2] << 8) | bytes[offset + 3];
      if (segmentLength < 2) {
        break;
      }

      if (marker == 0xE1 && _isExifApp1(bytes, offset + 4)) {
        final int payloadStart = offset + 4;
        final int payloadEnd = offset + 2 + segmentLength;
        // Skip the 6-byte "Exif\0\0" header to reach the TIFF header.
        final DateTime? parsed = _parseExifDateTime(
          bytes,
          payloadStart + 6,
          payloadEnd,
        );
        if (parsed != null) {
          return parsed;
        }
      }

      offset += 2 + segmentLength;
    }

    return null;
  }

  bool _isExifApp1(List<int> bytes, int start) {
    const List<int> header = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
    if (start + header.length > bytes.length) {
      return false;
    }
    for (int i = 0; i < header.length; i++) {
      if (bytes[start + i] != header[i]) {
        return false;
      }
    }
    return true;
  }

  DateTime? _parseExifDateTime(List<int> bytes, int start, int end) {
    if (end - start < 8) {
      return null;
    }

    final bool littleEndian = bytes[start] == 0x49 && bytes[start + 1] == 0x49;
    final bool bigEndian = bytes[start] == 0x4D && bytes[start + 1] == 0x4D;
    if (!littleEndian && !bigEndian) {
      return null;
    }

    int read16(int at) {
      final int hi = bytes[at];
      final int lo = bytes[at + 1];
      return littleEndian ? (lo << 8) | hi : (hi << 8) | lo;
    }

    int read32(int at) {
      if (littleEndian) {
        return bytes[at] |
            (bytes[at + 1] << 8) |
            (bytes[at + 2] << 16) |
            (bytes[at + 3] << 24);
      }
      return (bytes[at] << 24) |
          (bytes[at + 1] << 16) |
          (bytes[at + 2] << 8) |
          bytes[at + 3];
    }

    final int magic = read16(start + 2);
    if (magic != 42) {
      return null;
    }

    final int ifd0Offset = read32(start + 4);
    final int ifd0 = start + ifd0Offset;
    if (ifd0 + 2 > end) {
      return null;
    }

    final int entryCount = read16(ifd0);
    for (int i = 0; i < entryCount; i++) {
      final int entry = ifd0 + 2 + i * 12;
      if (entry + 12 > end) {
        break;
      }

      final int tag = read16(entry);
      final int type = read16(entry + 2);
      // DateTimeOriginal = tag 0x9003, ASCII type 2.
      if (tag == 0x9003 && type == 2) {
        final int valueOffset = read32(entry + 8);
        final int valueStart = start + valueOffset;
        final int maxLen = end - valueStart;
        if (maxLen < 19) {
          return null;
        }
        final String raw = String.fromCharCodes(
          bytes.sublist(valueStart, valueStart + 19),
        );
        return _parseExifDateString(raw);
      }
    }

    return null;
  }

  DateTime? _parseExifDateString(String raw) {
    // EXIF format: "YYYY:MM:DD HH:MM:SS"
    final match = RegExp(
      r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(raw);
    if (match == null) {
      return null;
    }
    try {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      );
    } catch (_) {
      return null;
    }
  }
}
