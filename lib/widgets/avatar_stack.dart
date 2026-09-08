import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/trip_models.dart';
import '../theme.dart';

/// Overlapping Neo-Brutalist circular avatar stack showing trip crew / participants.
class AvatarStack extends StatelessWidget {
  final List<CrewMember> crew;
  final List<String> fallbackNames;
  final double avatarSize;
  final double overlap;
  final int maxVisible;

  const AvatarStack({
    super.key,
    this.crew = const [],
    this.fallbackNames = const [],
    this.avatarSize = 34.0,
    this.overlap = 10.0,
    this.maxVisible = 4,
  });

  static const List<Color> _palette = [
    Color(0xFF7D8663), // Sage green
    Color(0xFFB08A3E), // Ochre
    Color(0xFF3E6B8A), // Slate blue
    Color(0xFFA5586B), // Berry
    Color(0xFFC05B3E), // Brick red
  ];

  @override
  Widget build(BuildContext context) {
    final List<_AvatarItem> items = [];

    if (crew.isNotEmpty) {
      for (int i = 0; i < crew.length; i++) {
        final member = crew[i];
        items.add(_AvatarItem(
          initial: member.initial.isNotEmpty
              ? member.initial
              : member.name.substring(0, 1).toUpperCase(),
          color: member.color,
          name: member.name,
        ));
      }
    } else if (fallbackNames.isNotEmpty) {
      for (int i = 0; i < fallbackNames.length; i++) {
        final name = fallbackNames[i];
        items.add(_AvatarItem(
          initial: name.isNotEmpty ? name[0].toUpperCase() : '?',
          color: _palette[i % _palette.length],
          name: name,
        ));
      }
    } else {
      items.add(const _AvatarItem(
        initial: 'YOU',
        color: BrutalTheme.primary,
        name: 'You',
      ));
    }

    final int visibleCount = items.length > maxVisible ? maxVisible : items.length;
    final int extraCount = items.length - visibleCount;

    return SizedBox(
      height: avatarSize,
      width: (visibleCount + (extraCount > 0 ? 1 : 0)) * (avatarSize - overlap) + overlap,
      child: Stack(
        children: [
          for (int i = 0; i < visibleCount; i++)
            Positioned(
              left: i * (avatarSize - overlap),
              child: _buildAvatarCircle(
                initial: items[i].initial,
                color: items[i].color,
                tooltip: items[i].name,
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: visibleCount * (avatarSize - overlap),
              child: _buildAvatarCircle(
                initial: '+$extraCount',
                color: BrutalTheme.backgroundDark,
                textColor: const Color(0xFFFFF8EC),
                tooltip: '$extraCount more',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle({
    required String initial,
    required Color color,
    Color textColor = Colors.white,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: BrutalTheme.paper2,
            width: 2.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: GoogleFonts.karla(
            fontSize: avatarSize * 0.40,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _AvatarItem {
  final String initial;
  final Color color;
  final String name;

  const _AvatarItem({
    required this.initial,
    required this.color,
    required this.name,
  });
}
