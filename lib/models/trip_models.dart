import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A draft of a new trip being created during onboarding.
class TripDraft {
  final String name;
  final String firstDay;
  final String lastDay;
  final int coverIndex;

  const TripDraft({
    this.name = '',
    this.firstDay = '',
    this.lastDay = '',
    this.coverIndex = 0,
  });

  TripDraft copyWith({
    String? name,
    String? firstDay,
    String? lastDay,
    int? coverIndex,
  }) {
    return TripDraft(
      name: name ?? this.name,
      firstDay: firstDay ?? this.firstDay,
      lastDay: lastDay ?? this.lastDay,
      coverIndex: coverIndex ?? this.coverIndex,
    );
  }

  bool get isValid => name.trim().isNotEmpty;
}

/// A friend that can be invited to a session.
class CrewMember {
  final String id;
  final String name;
  final String handle;
  final String initial;
  final Color color;
  final bool invited;

  const CrewMember({
    required this.id,
    required this.name,
    required this.handle,
    required this.initial,
    required this.color,
    this.invited = false,
  });

  CrewMember copyWith({bool? invited}) {
    return CrewMember(
      id: id,
      name: name,
      handle: handle,
      initial: initial,
      color: color,
      invited: invited ?? this.invited,
    );
  }
}

/// The type of media a guest can drop into a shared trip pool.
enum GuestDropType { photo, video, text }

/// A parsed guest drop with preserved capture metadata.
class GuestDrop {
  final GuestDropType type;
  final String author;
  final String content;
  final DateTime? capturedAt;
  final String? location;

  const GuestDrop({
    required this.type,
    required this.author,
    required this.content,
    this.capturedAt,
    this.location,
  });

  bool get isText => type == GuestDropType.text;
  bool get isPhoto => type == GuestDropType.photo;
  bool get isVideo => type == GuestDropType.video;
}

/// A fully created trip with its crew and session link.
class Trip {
  final String id;
  final String name;
  final String firstDay;
  final String lastDay;
  final int coverIndex;
  final List<CrewMember> crew;
  final String sessionLink;
  final DateTime createdAt;

  const Trip({
    required this.id,
    required this.name,
    required this.firstDay,
    required this.lastDay,
    required this.coverIndex,
    required this.crew,
    required this.sessionLink,
    required this.createdAt,
  });

  String get dateRange => '$firstDay – $lastDay';
}

/// In-memory store for user-created trips.
class TripStore extends ChangeNotifier {
  final List<Trip> _trips = [];

  List<Trip> get trips => List.unmodifiable(_trips);

  void addTrip(Trip trip) {
    _trips.add(trip);
    notifyListeners();
  }
}

/// A single memory in a trip diary: a note, optionally pinned to a place and
/// carrying a photo. Pinned memories (with [locationName]) become stops on the
/// trip route; nullable [latitude]/[longitude] are stored from day one so a
/// real map can be dropped in later without a data migration.
class TimelineMemory {
  final String id;
  final String author;
  final String time;
  final String text;

  /// 1-based day of the trip this memory belongs to (feed grouping).
  final int day;

  /// Optional date label shown in the day header (e.g. 'JUN 12').
  final String? dayDate;

  /// Place name of the pinned location milestone, if the memory was pinned.
  final String? locationName;
  final double? latitude;
  final double? longitude;

  final int likes;
  final bool likedByMe;

  /// Polaroid photo: either a remote [imageUrl], raw [photoBytes] (captured
  /// in-app), or a stylized photo wash when only [photoCaption] is set.
  final String? imageUrl;
  final String? photoCaption;
  final Uint8List? photoBytes;

  // Legacy timeline node styling (Evidence screen + canned fixtures).
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String? category;
  final Color? authorColor;

  final double rotationDegrees;

  const TimelineMemory({
    required this.id,
    required this.author,
    required this.time,
    required this.text,
    this.day = 1,
    this.dayDate,
    this.locationName,
    this.latitude,
    this.longitude,
    this.likes = 0,
    this.likedByMe = false,
    this.imageUrl,
    this.photoCaption,
    this.photoBytes,
    this.icon = Icons.notes,
    this.iconBg = const Color(0xFFF1E7D1),
    this.iconColor = Colors.black,
    this.category,
    this.authorColor,
    this.rotationDegrees = 0.0,
  });

  bool get hasPhoto => imageUrl != null || photoBytes != null;

  /// Whether this memory is a pin-able route stop.
  bool get isPinned => locationName != null && locationName!.trim().isNotEmpty;
}

/// A positioned label pin for the legacy Evidence map overlay.
class MapPin {
  final String memoryId;
  final String label;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;

  const MapPin({
    required this.memoryId,
    required this.label,
    this.left,
    this.top,
    this.right,
    this.bottom,
  });
}
