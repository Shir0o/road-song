import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/trip_models.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

/// Upload guardrails applied on the add path: a pick above these limits is
/// rejected with a clear message instead of being stored.
const int kMaxPhotoUploadBytes = 12 * 1024 * 1024;
const int kMaxVideoUploadBytes = 64 * 1024 * 1024;

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

/// Default photo source: the device camera via image_picker.
Future<Uint8List?> pickPhotoFromCamera() async {
  final XFile? picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}

/// Default video source: a short clip from the device library.
Future<Uint8List?> pickVideoFromLibrary() async {
  final XFile? picked = await ImagePicker().pickVideo(
    source: ImageSource.gallery,
    maxDuration: const Duration(seconds: 30),
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}

/// The three injectable media pick seams the Add Memory flow uses. Tests pass
/// fakes here so CI never touches a real codec; the defaults hit the device.
class MemoryMediaPickers {
  final Future<Uint8List?> Function() photoFromGallery;
  final Future<Uint8List?> Function() photoFromCamera;
  final Future<Uint8List?> Function() videoClip;

  const MemoryMediaPickers({
    this.photoFromGallery = pickPhotoFromGallery,
    this.photoFromCamera = pickPhotoFromCamera,
    this.videoClip = pickVideoFromLibrary,
  });
}

/// What the user composed in the Add Memory sheet; the caller turns this into
/// a full [TimelineMemory] (id/time/day/author are caller concerns).
class MemoryComposeResult {
  final String note;
  final String caption;
  final String? locationName;
  final Uint8List? photoBytes;
  final Uint8List? videoBytes;
  final MemoryType type;

  const MemoryComposeResult({
    this.note = '',
    this.caption = '',
    this.locationName,
    this.photoBytes,
    this.videoBytes,
    this.type = MemoryType.text,
  });
}

/// Caption/contributor edits made by the contributor on their own memory.
class MemoryEditResult {
  final String caption;
  final String contributor;

  const MemoryEditResult({required this.caption, required this.contributor});
}

/// Floating-`+` memory composer: media type + note + optional place pin.
Future<MemoryComposeResult?> showAddMemorySheet(
  BuildContext context, {
  required List<TimelineMemory> memories,
  required MemoryMediaPickers mediaPickers,
}) {
  return showModalBottomSheet<MemoryComposeResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _AddMemorySheet(memories: memories, mediaPickers: mediaPickers);
    },
  );
}

/// Edits the caption and contributor signature of an existing memory.
Future<MemoryEditResult?> showEditMemorySheet(
  BuildContext context, {
  required TimelineMemory memory,
}) {
  return showModalBottomSheet<MemoryEditResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _EditMemorySheet(memory: memory);
    },
  );
}

String _formatMegabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// The media kind the composer is currently set to capture.
enum MemorySource { gallery, camera, video, text }

class _AddMemorySheet extends StatefulWidget {
  final List<TimelineMemory> memories;
  final MemoryMediaPickers mediaPickers;

  const _AddMemorySheet({required this.memories, required this.mediaPickers});

  @override
  _AddMemorySheetState createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<_AddMemorySheet> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();

  MemorySource _source = MemorySource.text;
  bool _picking = false;
  Uint8List? _photoBytes;
  Uint8List? _videoBytes;
  String? _error;

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

  bool get _hasMedia => _photoBytes != null || _videoBytes != null;

  bool get _canSubmit =>
      !_picking && (_hasMedia || _noteController.text.trim().isNotEmpty);

  MemoryType get _resultType {
    if (_photoBytes != null) return MemoryType.photo;
    if (_videoBytes != null) return MemoryType.video;
    return MemoryType.text;
  }

  void _pickPlace(String place) {
    setState(() => _placeController.text = place);
  }

  Future<void> _selectSource(MemorySource source) async {
    setState(() {
      _source = source;
      _error = null;
      _photoBytes = null;
      _videoBytes = null;
    });
    if (source == MemorySource.text) return;

    setState(() => _picking = true);
    Uint8List? bytes;
    try {
      bytes = switch (source) {
        MemorySource.gallery => await widget.mediaPickers.photoFromGallery(),
        MemorySource.camera => await widget.mediaPickers.photoFromCamera(),
        MemorySource.video => await widget.mediaPickers.videoClip(),
        MemorySource.text => null,
      };
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (bytes == null || !mounted) return;

    final int limit = source == MemorySource.video
        ? kMaxVideoUploadBytes
        : kMaxPhotoUploadBytes;
    if (bytes.length > limit) {
      setState(() {
        _error = source == MemorySource.video
            ? 'That clip is ${_formatMegabytes(bytes!.length)} — keep clips '
                  'under ${_formatMegabytes(limit)}.'
            : 'That photo is ${_formatMegabytes(bytes!.length)} — keep photos '
                  'under ${_formatMegabytes(limit)}.';
      });
      return;
    }

    setState(() {
      if (source == MemorySource.video) {
        _videoBytes = bytes;
      } else {
        _photoBytes = bytes;
      }
    });
  }

  void _submit() {
    final String note = _noteController.text.trim();
    if (!_canSubmit) return;
    final String place = _placeController.text.trim();
    Navigator.of(context).pop(
      MemoryComposeResult(
        note: note,
        caption: _captionController.text.trim(),
        locationName: place.isEmpty ? null : place,
        photoBytes: _photoBytes,
        videoBytes: _videoBytes,
        type: _resultType,
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _captionController.dispose();
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
              Row(
                children: [
                  _SourceChip(
                    label: 'GALLERY',
                    icon: Icons.photo_library_outlined,
                    source: MemorySource.gallery,
                    active: _source == MemorySource.gallery,
                    onTap: _selectSource,
                  ),
                  const SizedBox(width: 7),
                  _SourceChip(
                    label: 'CAMERA',
                    icon: Icons.photo_camera_outlined,
                    source: MemorySource.camera,
                    active: _source == MemorySource.camera,
                    onTap: _selectSource,
                  ),
                  const SizedBox(width: 7),
                  _SourceChip(
                    label: 'VIDEO',
                    icon: Icons.movie_outlined,
                    source: MemorySource.video,
                    active: _source == MemorySource.video,
                    onTap: _selectSource,
                  ),
                  const SizedBox(width: 7),
                  _SourceChip(
                    label: 'LORE',
                    icon: Icons.notes,
                    source: MemorySource.text,
                    active: _source == MemorySource.text,
                    onTap: _selectSource,
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('memory-upload-error'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6DFD8),
                    border: Border.all(color: BrutalTheme.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.primary,
                    ),
                  ),
                ),
              ],
              if (_hasMedia) ...[
                const SizedBox(height: 10),
                _buildAttachment(),
              ],
              const SizedBox(height: 12),
              Container(
                decoration: BrutalTheme.brutalDecoration(
                  color: BrutalTheme.card,
                  borderWidth: 1.0,
                  showShadow: false,
                ),
                child: TextField(
                  key: const ValueKey('memory-note'),
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
              const SizedBox(height: 10),
              Container(
                decoration: BrutalTheme.brutalDecoration(
                  color: BrutalTheme.card,
                  borderWidth: 1.0,
                  showShadow: false,
                ),
                child: TextField(
                  key: const ValueKey('memory-caption'),
                  controller: _captionController,
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
                    hintText: 'Add a caption (optional)',
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
                  key: const ValueKey('memory-place'),
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

  Widget _buildAttachment() {
    final Uint8List? video = _videoBytes;
    if (video != null) {
      return Container(
        key: const ValueKey('video-attachment'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: BrutalTheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: BrutalTheme.paper2,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.movie_outlined,
              size: 16,
              color: BrutalTheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Short clip attached · ${_formatMegabytes(video.length)}',
                style: GoogleFonts.karla(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: BrutalTheme.inkBlack,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('photo-attachment'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: BrutalTheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(10),
        color: BrutalTheme.paper2,
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: BrutalTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Photo attached',
              style: GoogleFonts.karla(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: BrutalTheme.inkBlack,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image(
              image: MemoryImage(_photoBytes!),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

/// A media-type chip; tapping it opens the matching picker (or clears media
/// for lore entries).
class _SourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final MemorySource source;
  final bool active;
  final ValueChanged<MemorySource> onTap;

  const _SourceChip({
    required this.label,
    required this.icon,
    required this.source,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        key: ValueKey('memory-type-${source.name}'),
        onTap: () => onTap(source),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? BrutalTheme.primary : BrutalTheme.paper2,
            border: Border.all(
              color: active ? BrutalTheme.primary : const Color(0xFFCBBB97),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? Colors.white : BrutalTheme.graphite,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: active ? Colors.white : BrutalTheme.inkBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Caption + contributor editor for the contributor's own memory.
class _EditMemorySheet extends StatefulWidget {
  final TimelineMemory memory;

  const _EditMemorySheet({required this.memory});

  @override
  _EditMemorySheetState createState() => _EditMemorySheetState();
}

class _EditMemorySheetState extends State<_EditMemorySheet> {
  late final TextEditingController _captionController;
  late final TextEditingController _contributorController;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(
      text: widget.memory.displayCaption,
    );
    _contributorController = TextEditingController(
      text: widget.memory.contributor,
    );
  }

  void _save() {
    Navigator.of(context).pop(
      MemoryEditResult(
        caption: _captionController.text.trim(),
        contributor: _contributorController.text.trim().isEmpty
            ? widget.memory.contributor
            : _contributorController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    _contributorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Edit memory',
                style: GoogleFonts.caveat(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: BrutalTheme.inkBlack,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'CAPTION',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                  color: BrutalTheme.graphite,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BrutalTheme.brutalDecoration(
                  color: BrutalTheme.card,
                  borderWidth: 1.0,
                  showShadow: false,
                ),
                child: TextField(
                  key: const ValueKey('edit-caption'),
                  controller: _captionController,
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
                    hintText: 'Say what this moment was',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'SIGNED BY',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                  color: BrutalTheme.graphite,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BrutalTheme.brutalDecoration(
                  color: BrutalTheme.card,
                  borderWidth: 1.0,
                  showShadow: false,
                ),
                child: TextField(
                  key: const ValueKey('edit-contributor'),
                  controller: _contributorController,
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
                    hintText: 'Your name',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BrutalButton(
                color: BrutalTheme.primary,
                onPressed: _save,
                child: Text(
                  'SAVE',
                  style: GoogleFonts.karla(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
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
