import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/trip_models.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

/// What the user composed in the Add Memory sheet; the caller turns this into
/// a full [TimelineMemory] (id/time/day/author are caller concerns).
class MemoryComposeResult {
  final String note;
  final String? locationName;
  final Uint8List? photoBytes;

  const MemoryComposeResult({
    required this.note,
    this.locationName,
    this.photoBytes,
  });
}

/// Default photo source: the device gallery via image_picker.
Future<Uint8List?> pickPhotoFromGallery() async {
  final XFile? picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}

/// Floating-`+` memory composer: note + optional location pin + optional photo.
Future<MemoryComposeResult?> showAddMemorySheet(
  BuildContext context, {
  required List<TimelineMemory> memories,
  required Future<Uint8List?> Function() pickPhotoBytes,
}) {
  return showModalBottomSheet<MemoryComposeResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _AddMemorySheet(
        memories: memories,
        pickPhotoBytes: pickPhotoBytes,
      );
    },
  );
}

class _AddMemorySheet extends StatefulWidget {
  final List<TimelineMemory> memories;
  final Future<Uint8List?> Function() pickPhotoBytes;

  const _AddMemorySheet({
    required this.memories,
    required this.pickPhotoBytes,
  });

  @override
  _AddMemorySheetState createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<_AddMemorySheet> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();

  bool _picking = false;
  Uint8List? _photoBytes;

  /// Places already pinned on the trip, for one-tap pinning.
  List<String> get _knownPlaces {
    final seen = <String>{};
    final places = <String>[];
    for (final memory in widget.memories) {
      if (memory.isPinned && seen.add(memory.locationName!)) {
        places.add(memory.locationName!);
      }
    }
    return places;
  }

  bool get _canSubmit => _noteController.text.trim().isNotEmpty && !_picking;

  void _pickPlace(String place) {
    setState(() => _placeController.text = place);
  }

  Future<void> _attachPhoto() async {
    setState(() => _picking = true);
    Uint8List? bytes;
    try {
      bytes = await widget.pickPhotoBytes();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (bytes != null && mounted) {
      setState(() => _photoBytes = bytes);
    }
  }

  void _submit() {
    final String note = _noteController.text.trim();
    if (note.isEmpty) return;
    final String? place = _placeController.text.trim();
    Navigator.of(context).pop(
      MemoryComposeResult(
        note: note,
        locationName: place == null || place.isEmpty ? null : place,
        photoBytes: _photoBytes,
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> places = _knownPlaces;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: BrutalTheme.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Color(0x4D2E2418),
              offset: Offset(0, -14),
              blurRadius: 44,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 42),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8C9A8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Text(
                'Add a memory',
                style: GoogleFonts.caveat(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: BrutalTheme.inkBlack,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BrutalTheme.brutalDecoration(
                  color: BrutalTheme.card,
                  borderWidth: 1.0,
                  showShadow: false,
                ),
                child: TextField(
                  controller: _noteController,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.karla(
                    fontSize: 14.5,
                    height: 1.5,
                    color: BrutalTheme.inkBlack,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    hintText: 'What happened? The funnier the better…',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'PIN A PLACE',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                  color: BrutalTheme.graphite,
                ),
              ),
              const SizedBox(height: 7),
              if (places.isNotEmpty) ...[
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final String place in places)
                      _PlaceChip(
                        place: place,
                        active:
                            _placeController.text.trim() == place,
                        onTap: () => _pickPlace(place),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
              ],
              Container(
                decoration: BrutalTheme.brutalDecoration(
                  color: BrutalTheme.card,
                  borderWidth: 1.0,
                  showShadow: false,
                ),
                child: TextField(
                  controller: _placeController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.karla(
                    fontSize: 13.5,
                    color: BrutalTheme.inkBlack,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    hintText: 'e.g. Rua Garrett, Lisbon',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                key: const ValueKey('attach-photo'),
                onTap: _picking ? null : _attachPhoto,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _photoBytes != null
                          ? BrutalTheme.primary
                          : const Color(0xFFCBBB97),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: _photoBytes != null
                        ? BrutalTheme.paper2
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _picking
                            ? Icons.hourglass_top
                            : (_photoBytes != null
                                ? Icons.check_circle
                                : Icons.photo_camera_outlined),
                        size: 16,
                        color: _photoBytes != null
                            ? BrutalTheme.primary
                            : BrutalTheme.graphite,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _picking
                              ? 'Choosing photo…'
                              : (_photoBytes != null
                                  ? 'Photo attached'
                                  : 'Attach a photo'),
                          style: GoogleFonts.karla(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BrutalTheme.inkBlack,
                          ),
                        ),
                      ),
                      if (_photoBytes != null)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE1D4B6),
                              width: 1,
                            ),
                            image: DecorationImage(
                              image: MemoryImage(_photoBytes!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: _canSubmit ? 1.0 : 0.4,
                child: BrutalButton(
                  color: BrutalTheme.primary,
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(
                    'Paste it in the scrapbook',
                    style: GoogleFonts.karla(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceChip extends StatelessWidget {
  final String place;
  final bool active;
  final VoidCallback onTap;

  const _PlaceChip({
    required this.place,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('place-chip-$place'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: active ? BrutalTheme.primary : BrutalTheme.paper2,
          border: Border.all(
            color: active ? BrutalTheme.primary : const Color(0xFFCBBB97),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '⚑ $place',
          style: GoogleFonts.karla(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : BrutalTheme.inkBlack,
          ),
        ),
      ),
    );
  }
}
