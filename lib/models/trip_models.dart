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
