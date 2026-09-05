import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/trip_models.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

/// A pinned place on the route: the first memory that pinned [placeName],
/// in chronological trip order.
class RouteStop {
  final String id;
  final String placeName;
  final String author;
  final String time;
  final String text;
  final int day;
  final String? dayDate;
  final double? latitude;
  final double? longitude;

  const RouteStop({
    required this.id,
    required this.placeName,
    required this.author,
    required this.time,
    required this.text,
    required this.day,
    this.dayDate,
    this.latitude,
    this.longitude,
  });
}

/// Distinct pinned places in order of first appearance. Unpinned memories
/// never appear on the route.
List<RouteStop> buildRouteStops(List<TimelineMemory> memories) {
  final seen = <String>{};
  final stops = <RouteStop>[];
  for (final memory in memories) {
    if (!memory.isPinned) continue;
    if (!seen.add(memory.locationName!)) continue;
    stops.add(
      RouteStop(
        id: memory.id,
        placeName: memory.locationName!,
        author: memory.author,
        time: memory.time,
        text: memory.text,
        day: memory.day,
        dayDate: memory.dayDate,
        latitude: memory.latitude,
        longitude: memory.longitude,
      ),
    );
  }
  return stops;
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadiusKm = 6371.0;
  final double dLat = _toRadians(lat2 - lat1);
  final double dLng = _toRadians(lng2 - lng1);
  final double a = math.pow(math.sin(dLat / 2), 2).toDouble() +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.pow(math.sin(dLng / 2), 2).toDouble();
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Odometer: summed great-circle distance between consecutive stops that
/// carry coordinates. Stops without coordinates are skipped over.
double routeKilometers(List<RouteStop> stops) {
  double total = 0;
  RouteStop? previous;
  for (final stop in stops) {
    if (stop.latitude != null && stop.longitude != null) {
      if (previous != null &&
          previous.latitude != null &&
          previous.longitude != null) {
        total += _haversineKm(
          previous.latitude!,
          previous.longitude!,
          stop.latitude!,
          stop.longitude!,
        );
      }
      previous = stop;
    }
  }
  return total;
}

/// Where each stop marker sits on the [RouteMapView] canvas. Stops that all
/// carry coordinates are projected with an equirectangular fit; otherwise the
/// ordered stops are laid out along a deterministic S-curve.
List<Offset> routeStopOffsets(List<RouteStop> stops, Size size) {
  const double pad = 64.0;
  if (stops.isEmpty) return const [];
  if (stops.length == 1) {
    return [Offset(size.width / 2, size.height / 2)];
  }

  final bool allHaveCoords = stops.every(
    (stop) => stop.latitude != null && stop.longitude != null,
  );
  if (allHaveCoords) {
    final double minLat =
        stops.map((s) => s.latitude!).reduce(math.min);
    final double maxLat =
        stops.map((s) => s.latitude!).reduce(math.max);
    final double minLng =
        stops.map((s) => s.longitude!).reduce(math.min);
    final double maxLng =
        stops.map((s) => s.longitude!).reduce(math.max);

    final double spanLat = math.max(maxLat - minLat, 1e-6);
    final double spanLng = math.max(maxLng - minLng, 1e-6);

    // Fit the lat/lng box inside the padded canvas preserving its aspect.
    final double boxW = size.width - pad * 2;
    final double boxH = size.height - pad * 2;
    final double scale = math.min(boxW / spanLng, boxH / spanLat);
    final double drawnW = spanLng * scale;
    final double drawnH = spanLat * scale;
    final double originX = (size.width - drawnW) / 2;
    final double originY = (size.height - drawnH) / 2;

    return [
      for (final stop in stops)
        Offset(
          originX + (stop.longitude! - minLng) * scale,
          originY + (maxLat - stop.latitude!) * scale,
        ),
    ];
  }

  final List<Offset> offsets = [];
  for (int i = 0; i < stops.length; i++) {
    final double t = stops.length == 1 ? 0.5 : i / (stops.length - 1);
    final double x = pad + t * (size.width - pad * 2);
    final double sway = math.sin(i * 1.25) * size.height * 0.2;
    offsets.add(Offset(x, size.height / 2 + sway));
  }
  return offsets;
}

/// Route tab: stylized route map of the trip's pinned places with numbered
/// pins, tap callouts, stop list, and a distance odometer.
class RouteTab extends StatefulWidget {
  final String tripName;
  final List<TimelineMemory> memories;
  final VoidCallback onOpenDiary;

  const RouteTab({
    Key? key,
    required this.tripName,
    required this.memories,
    required this.onOpenDiary,
  }) : super(key: key);

  @override
  _RouteTabState createState() => _RouteTabState();
}

class _RouteTabState extends State<RouteTab> {
  String? _selectedId;

  List<RouteStop> get _stops => buildRouteStops(widget.memories);

  @override
  Widget build(BuildContext context) {
    final List<RouteStop> stops = _stops;
    final double km = routeKilometers(stops);

    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: GrainOverlay(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(stops.length, km),
            Expanded(
              child: stops.isEmpty
                  ? _buildEmptyState(widget.memories.isEmpty)
                  : _buildRoute(stops, km),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int stopCount, double km) {
    final String summary = km > 0
        ? '$stopCount ${stopCount == 1 ? 'stop' : 'stops'} · ${km.round()} km'
        : '$stopCount ${stopCount == 1 ? 'stop' : 'stops'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tripName.toUpperCase(),
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: BrutalTheme.graphite,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'The route',
            style: GoogleFonts.instrumentSerif(
              fontSize: 27,
              color: BrutalTheme.inkBlack,
            ),
          ),
          Text(
            summary,
            key: const ValueKey('route-summary'),
            style: GoogleFonts.caveat(
              fontSize: 19,
              color: BrutalTheme.graphite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoute(List<RouteStop> stops, double km) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        RouteMapView(
          stops: stops,
          selectedId: _selectedId,
          onSelect: (String? id) => setState(() => _selectedId = id),
        ),
        const SizedBox(height: 18),
        for (final (int index, RouteStop stop) in stops.indexed)
          _buildStopRow(index, stop),
      ],
    );
  }

  Widget _buildStopRow(int index, RouteStop stop) {
    final bool selected = _selectedId == stop.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GestureDetector(
        key: ValueKey('stop-row-${stop.id}'),
        onTap: () => setState(() => _selectedId = selected ? null : stop.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: BrutalTheme.card,
            border: Border.all(
              color: selected ? BrutalTheme.primary : const Color(0xFFEBDFC6),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? BrutalTheme.primary : Colors.transparent,
                  border: Border.all(color: BrutalTheme.primary, width: 2),
                ),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : BrutalTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.placeName,
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 18,
                        color: BrutalTheme.inkBlack,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stop.author} · ${stop.time}',
                      style: GoogleFonts.karla(
                        fontSize: 11.5,
                        color: BrutalTheme.graphite,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _excerpt(stop.text),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.caveat(
                    fontSize: 17,
                    color: BrutalTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool noMemoriesAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 44,
              color: BrutalTheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              noMemoriesAtAll
                  ? 'No memories yet — the route starts with the first pinned place.'
                  : 'No pinned places yet. Pin a place to a memory and it becomes a stop on the route.',
              textAlign: TextAlign.center,
              style: GoogleFonts.karla(
                fontSize: 14.5,
                height: 1.5,
                color: BrutalTheme.graphite,
              ),
            ),
            const SizedBox(height: 18),
            BrutalButton(
              color: BrutalTheme.primary,
              onPressed: widget.onOpenDiary,
              child: Text(
                'ADD A MEMORY',
                style: GoogleFonts.karla(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _excerpt(String text) {
    final String trimmed = text.trim();
    if (trimmed.length <= 22) return trimmed;
    return '${trimmed.substring(0, 22).trimRight()}…';
  }
}

/// The stylized map: striped brutalist ground, the ordered route polyline and
/// numbered stop markers with place labels. Fully offline, no tile imagery.
class RouteMapView extends StatelessWidget {
  final List<RouteStop> stops;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const RouteMapView({
    Key? key,
    required this.stops,
    required this.selectedId,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE1D4B6), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          final List<Offset> offsets = routeStopOffsets(stops, size);
          final RouteStop? selected = selectedId == null
              ? null
              : stops.where((s) => s.id == selectedId).firstOrNull;

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _RouteGroundPainter()),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _RouteLinePainter(offsets: offsets),
                ),
              ),
              for (final (int index, RouteStop stop) in stops.indexed)
                Positioned(
                  left: offsets[index].dx,
                  top: offsets[index].dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: GestureDetector(
                      key: ValueKey('route-pin-${stop.id}'),
                      onTap: () {
                        onSelect(selectedId == stop.id ? null : stop.id);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: BrutalTheme.primary,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66433729),
                                  offset: Offset(0, 4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.karla(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 128),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: BrutalTheme.card,
                              border: Border.all(
                                color: const Color(0xFFE1D4B6),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              stop.placeName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.karla(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: BrutalTheme.inkBlack,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (selected != null)
                Positioned(
                  left: 10,
                  right: 10,
                  top: 10,
                  child: _StopCallout(stop: selected),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StopCallout extends StatelessWidget {
  final RouteStop stop;

  const _StopCallout({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('pin-callout'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BrutalTheme.yellow,
        border: Border.all(color: BrutalTheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33433729),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '⚑ ${stop.placeName.toUpperCase()}',
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: BrutalTheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stop.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.karla(
              fontSize: 12.5,
              height: 1.4,
              color: BrutalTheme.inkBlack,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diagonal paper stripes — the design's flat "map placeholder" ground.
class _RouteGroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const List<Color> stripeColors = [
      Color(0xFFEAE3D0),
      Color(0xFFF0EADA),
    ];
    final Paint paint = Paint()..strokeWidth = 24;
    int band = 0;
    for (double x = -size.height; x < size.width + size.height; x += 24) {
      paint.color = stripeColors[band % 2];
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
      band++;
    }
  }

  @override
  bool shouldRepaint(covariant _RouteGroundPainter oldDelegate) => false;
}

/// The journey polyline through the ordered stop offsets.
class _RouteLinePainter extends CustomPainter {
  final List<Offset> offsets;

  const _RouteLinePainter({required this.offsets});

  @override
  void paint(Canvas canvas, Size size) {
    if (offsets.length < 2) return;
    final Path path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final Offset offset in offsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = BrutalTheme.primary.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) {
    return oldDelegate.offsets != offsets;
  }
}
