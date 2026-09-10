import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/trip_models.dart';
import '../services/audio_seam.dart';
import '../services/pending_upload_store.dart';
import '../services/remote_trip_store.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';
import 'guest_consume_screen.dart';

/// Upload guardrails for the guest web path — mirrors the app's
/// [kMaxPhotoUploadBytes] / [kMaxVideoUploadBytes] from add_memory_sheet.dart.
const int kGuestMaxPhotoBytes = 12 * 1024 * 1024;
const int kGuestMaxVideoBytes = 64 * 1024 * 1024;

/// The two injectable media pick seams the guest portal uses. Tests pass
/// fakes here so CI never touches a real file picker; the defaults attach a
/// small fixture so the flow is exercisable end to end in the prototype.
class GuestMediaPickers {
  final Future<Uint8List?> Function() photo;
  final Future<Uint8List?> Function() video;

  const GuestMediaPickers({
    this.photo = _pickDemoPhoto,
    this.video = _pickDemoVideo,
  });
}

Future<Uint8List?> _pickDemoPhoto() async => Uint8List.fromList(const [
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
]);

Future<Uint8List?> _pickDemoVideo() async =>
    Uint8List.fromList(List.filled(4096, 7));

/// The guest experience: the SAME Flutter web build in an anonymous guest
/// mode (spec decision 7, option A — one codebase, one deploy). A guest
/// opening `roadsong.app/t/<code>` on any device reaches this screen, sees
/// the trip name and what to do, and can add a photo, a short video, or a
/// text memory from a phone browser. Uploads show progress and a retry after
/// a dropped connection.
class GuestPortalScreen extends StatefulWidget {
  final String tripCode;
  final TripStoreClient client;
  final GuestMediaPickers mediaPickers;
  final DateTime Function() now;

  /// The audio seam for the visitor's memorial player. Tests inject a fake
  /// so CI never touches a real codec; production defaults to
  /// audioplayers-backed playback.
  final AudioSeam? audioSeam;

  const GuestPortalScreen({
    Key? key,
    required this.tripCode,
    required this.client,
    this.mediaPickers = const GuestMediaPickers(),
    this.now = DateTime.now,
    this.audioSeam,
  }) : super(key: key);

  @override
  _GuestPortalScreenState createState() => _GuestPortalScreenState();
}

class _GuestPortalScreenState extends State<GuestPortalScreen> {
  Trip? _trip;
  String? _loadError;
  bool _loading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();

  MemoryType _type = MemoryType.text;
  Uint8List? _mediaBytes;
  String? _mediaContentType;
  String? _mediaError;

  bool _uploading = false;
  double _progress = 0;
  String? _uploadError;
  String? _successMessage;

  /// The upload that failed and was queued (issue #31): it survives app
  /// restarts through [PendingUploadStore] and is re-shown with a retry so
  /// a dropped connection never silently loses the guest's input.
  PendingUpload? _pendingUpload;

  /// The visitor's current mode: upload (add memories) or consume (listen +
  /// browse the memorial). A trip with a published song opens in consume
  /// mode; the visitor can switch to upload to contribute.
  bool _consumeMode = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
    _loadPendingUpload();
    // Rebuild when the user types so the submit button enables/disables.
    _nameController.addListener(_onInputChanged);
    _noteController.addListener(_onInputChanged);
    _captionController.addListener(_onInputChanged);
    _placeController.addListener(_onInputChanged);
  }

  /// Restores a queued upload for this trip after a restart (issue #31): the
  /// failed upload is re-shown with its retry affordance instead of being
  /// silently lost. Best-effort: a storage failure never blocks the portal.
  Future<void> _loadPendingUpload() async {
    try {
      final List<PendingUpload> pending = await PendingUploadStore().loadFor(
        widget.tripCode,
      );
      if (!mounted || pending.isEmpty) return;
      setState(() {
        _pendingUpload = pending.first;
      });
    } catch (_) {
      // No persisted queue (e.g. storage unavailable): nothing to restore.
    }
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onInputChanged);
    _noteController.removeListener(_onInputChanged);
    _captionController.removeListener(_onInputChanged);
    _placeController.removeListener(_onInputChanged);
    _nameController.dispose();
    _noteController.dispose();
    _captionController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final Trip trip = await widget.client.fetchTrip(widget.tripCode);
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _loading = false;
        // A trip with a published song opens in consume mode: the visitor
        // can listen and browse immediately, and switch to upload to add
        // their own memories.
        _consumeMode = trip.memorialSong != null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e is TripStoreHttpException
            ? e.message
            : 'Could not reach the trip. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  void _pickMedia(MemoryType type, Uint8List bytes, String contentType) {
    final int limit = type == MemoryType.video
        ? kGuestMaxVideoBytes
        : kGuestMaxPhotoBytes;
    if (bytes.length > limit) {
      setState(() {
        _type = type;
        _mediaBytes = null;
        _mediaContentType = null;
        _mediaError = type == MemoryType.video
            ? 'That clip is ${_mb(bytes.length)} — keep clips under 64.0 MB.'
            : 'That photo is ${_mb(bytes.length)} — keep photos under 12.0 MB.';
      });
      return;
    }
    setState(() {
      _type = type;
      _mediaBytes = bytes;
      _mediaContentType = contentType;
      _mediaError = null;
    });
  }

  String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  bool get _canSubmit {
    if (_uploading) return false;
    if (_type != MemoryType.text && _mediaBytes == null) return false;
    if (_type == MemoryType.text && _noteController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final String contributor = _nameController.text.trim();
    final String author = contributor.isEmpty
        ? '@guest'
        : '@${contributor.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}';
    final String note = _noteController.text.trim();
    final String caption = _captionController.text.trim();
    final String place = _placeController.text.trim();

    setState(() {
      _uploading = true;
      _progress = 0;
      _uploadError = null;
      _successMessage = null;
    });

    final TripUploadResult result = await uploadGuestMemoryTo(
      widget.client,
      tripCode: widget.tripCode,
      contributor: contributor.isEmpty ? 'Guest' : contributor,
      author: author,
      type: _type,
      bytes: _mediaBytes ?? Uint8List(0),
      contentType: _mediaContentType ?? 'text/plain',
      caption: caption,
      text: note,
      locationName: place.isEmpty ? null : place,
      now: widget.now,
      onProgress: (double p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;

    if (result.isSuccess) {
      // A queued upload for this trip was delivered: clear the queue.
      // Best-effort: a storage failure never blocks the upload flow.
      try {
        await PendingUploadStore().remove(widget.tripCode);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _pendingUpload = null;
        _successMessage = _type == MemoryType.text
            ? 'Added to the trip. Thank you!'
            : 'Uploaded to the trip. Thank you!';
        _noteController.clear();
        _captionController.clear();
        _placeController.clear();
        _mediaBytes = null;
        _mediaContentType = null;
        _type = MemoryType.text;
      });
    } else {
      // The upload failed: queue it (persisted, so it survives a restart)
      // and show the retry affordance. The guest's input is never lost.
      final PendingUpload pending = PendingUpload(
        tripCode: widget.tripCode,
        contributor: contributor.isEmpty ? 'Guest' : contributor,
        author: author,
        type: _type,
        bytes: _mediaBytes ?? Uint8List(0),
        contentType: _mediaContentType ?? 'text/plain',
        caption: caption,
        text: note,
        locationName: place.isEmpty ? null : place,
        createdAt: widget.now(),
      );
      // Best-effort: a storage failure never blocks the upload flow.
      try {
        await PendingUploadStore().save(pending);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _pendingUpload = pending;
        _uploadError = result.error;
      });
    }
  }

  /// Retries the queued upload (issue #31): the persisted payload is
  /// re-sent; on success the queue entry is cleared and the memory lands.
  Future<void> _retryPending() async {
    final PendingUpload? pending = _pendingUpload;
    if (pending == null || _uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _uploadError = null;
      _successMessage = null;
    });
    final TripUploadResult result = await uploadGuestMemoryTo(
      widget.client,
      tripCode: pending.tripCode,
      contributor: pending.contributor,
      author: pending.author,
      type: pending.type,
      bytes: pending.bytes,
      contentType: pending.contentType,
      caption: pending.caption,
      text: pending.text,
      locationName: pending.locationName,
      latitude: pending.latitude,
      longitude: pending.longitude,
      now: widget.now,
      onProgress: (double p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    if (result.isSuccess) {
      // Best-effort: a storage failure never blocks the upload flow.
      try {
        await PendingUploadStore().remove(pending.tripCode);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _pendingUpload = null;
        _successMessage = pending.type == MemoryType.text
            ? 'Added to the trip. Thank you!'
            : 'Uploaded to the trip. Thank you!';
      });
    } else {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: Text(
                  'Opening the trip…',
                  style: TextStyle(color: BrutalTheme.graphite),
                ),
              )
            : _loadError != null
            ? _buildLoadError()
            : _consumeMode
            ? _buildConsume()
            : _buildPortal(),
      ),
    );
  }

  /// The visitor consume mode: listen to the finished song and browse the
  /// diary through the link, with a switch back to the upload form.
  Widget _buildConsume() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Spacer(),
              GestureDetector(
                key: const ValueKey('guest-upload-mode'),
                onTap: () => setState(() => _consumeMode = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: BrutalTheme.paper2,
                    border: Border.all(color: const Color(0xFFDCCDAC)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ADD YOUR MEMORIES',
                    style: GoogleFonts.spaceMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GuestConsumeScreen(
            trip: _trip!,
            audioSeam: widget.audioSeam ?? AudioplayersAudioSeam(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DymoLabel(text: 'TRIP NOT FOUND', fontSize: 14),
            const SizedBox(height: 14),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.karla(
                fontSize: 14,
                height: 1.5,
                color: BrutalTheme.inkBlack,
              ),
            ),
            const SizedBox(height: 18),
            BrutalButton(
              onPressed: _loadTrip,
              child: Text(
                'TRY AGAIN',
                style: GoogleFonts.spaceMono(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortal() {
    final Trip trip = _trip!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ROAD SONG',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: BrutalTheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            trip.name.toUpperCase(),
            style: GoogleFonts.instrumentSerif(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: BrutalTheme.inkBlack,
            ),
          ),
          Transform.rotate(
            angle: -2 * 3.14159 / 180,
            child: Text(
              'every wrong turn, kept forever',
              style: GoogleFonts.caveat(
                fontSize: 19,
                color: BrutalTheme.graphite,
              ),
            ),
          ),
          const SizedBox(height: 18),
          BrutalCard(
            color: BrutalTheme.card,
            padding: const EdgeInsets.all(16),
            child: Text(
              'You were on this trip. Drop your photos, short clips and '
              'inside jokes here — they land straight in the trip diary.',
              style: GoogleFonts.karla(
                fontSize: 14,
                height: 1.55,
                color: BrutalTheme.inkBlack,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_successMessage != null) ...[
            Container(
              key: const ValueKey('guest-success'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE3EBD8),
                border: Border.all(color: const Color(0xFF7D8663), width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _successMessage!,
                style: GoogleFonts.karla(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3E4A2E),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_pendingUpload != null) ...[
            Container(
              key: const ValueKey('guest-pending-upload'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6E3DC),
                border: Border.all(color: BrutalTheme.primary, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'One upload is waiting to go through',
                    style: GoogleFonts.karla(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'It was saved when your connection dropped — it will '
                    'still reach the trip.',
                    style: GoogleFonts.karla(
                      fontSize: 12.5,
                      height: 1.45,
                      color: const Color(0xFF57493A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  BrutalButton(
                    key: const ValueKey('guest-retry-pending'),
                    height: 40,
                    onPressed: _retryPending,
                    child: Text(
                      'RETRY NOW',
                      style: GoogleFonts.spaceMono(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildNameField(),
          const SizedBox(height: 14),
          _buildTypePicker(),
          const SizedBox(height: 14),
          if (_type != MemoryType.text) _buildMediaPicker(),
          if (_type == MemoryType.text) _buildNoteField(),
          if (_type != MemoryType.text) _buildCaptionField(),
          _buildPlaceField(),
          if (_mediaError != null) ...[
            const SizedBox(height: 10),
            Text(
              _mediaError!,
              key: const ValueKey('guest-media-error'),
              style: GoogleFonts.karla(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: BrutalTheme.primary,
              ),
            ),
          ],
          if (_uploadError != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('guest-upload-error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6E3DC),
                border: Border.all(color: BrutalTheme.primary, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _uploadError!,
                    style: GoogleFonts.karla(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BrutalButton(
                    height: 40,
                    onPressed: _submit,
                    child: Text(
                      'RETRY',
                      style: GoogleFonts.spaceMono(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_uploading) ...[
            _buildProgress(),
          ] else
            BrutalButton(
              key: const ValueKey('guest-submit'),
              onPressed: _canSubmit ? _submit : null,
              child: Text(
                _type == MemoryType.text
                    ? 'ADD TO THE TRIP'
                    : 'UPLOAD TO THE TRIP',
                style: GoogleFonts.spaceMono(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      key: const ValueKey('guest-name'),
      controller: _nameController,
      style: GoogleFonts.karla(fontSize: 14, color: BrutalTheme.inkBlack),
      decoration: InputDecoration(
        labelText: 'Your name',
        labelStyle: GoogleFonts.karla(
          fontSize: 12,
          color: BrutalTheme.graphite,
        ),
        hintText: 'How should we credit you?',
        hintStyle: GoogleFonts.karla(
          fontSize: 13,
          color: BrutalTheme.graphite.withOpacity(0.6),
        ),
        filled: true,
        fillColor: BrutalTheme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1D4B6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1D4B6)),
        ),
      ),
    );
  }

  Widget _buildTypePicker() {
    return Row(
      children: [
        _TypeChip(
          label: 'PHOTO',
          icon: Icons.photo_library_outlined,
          active: _type == MemoryType.photo,
          onTap: () => setState(() {
            _type = MemoryType.photo;
            _mediaError = null;
          }),
        ),
        const SizedBox(width: 8),
        _TypeChip(
          label: 'VIDEO',
          icon: Icons.videocam_outlined,
          active: _type == MemoryType.video,
          onTap: () => setState(() {
            _type = MemoryType.video;
            _mediaError = null;
          }),
        ),
        const SizedBox(width: 8),
        _TypeChip(
          label: 'TEXT',
          icon: Icons.edit_note,
          active: _type == MemoryType.text,
          onTap: () => setState(() {
            _type = MemoryType.text;
            _mediaError = null;
          }),
        ),
      ],
    );
  }

  Widget _buildMediaPicker() {
    final bool isVideo = _type == MemoryType.video;
    final bool attached = _mediaBytes != null;
    return Container(
      key: const ValueKey('guest-media-picker'),
      padding: const EdgeInsets.all(14),
      decoration: BrutalTheme.brutalDecoration(
        color: BrutalTheme.card,
        borderWidth: 1,
        showShadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVideo ? 'SHORT VIDEO CLIP' : 'PHOTO',
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
              color: BrutalTheme.graphite,
            ),
          ),
          const SizedBox(height: 8),
          if (attached)
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF7D8663)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVideo ? 'Clip attached' : 'Photo attached',
                    style: GoogleFonts.karla(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              isVideo
                  ? 'Pick a short clip from your phone (under 64.0 MB).'
                  : 'Pick a photo from your phone (under 12.0 MB).',
              style: GoogleFonts.karla(
                fontSize: 13,
                color: BrutalTheme.graphite,
              ),
            ),
          const SizedBox(height: 10),
          BrutalButton(
            height: 42,
            color: BrutalTheme.yellow,
            onPressed: () async {
              final Uint8List? bytes = isVideo
                  ? await widget.mediaPickers.video()
                  : await widget.mediaPickers.photo();
              if (bytes == null || !mounted) return;
              _pickMedia(_type, bytes, isVideo ? 'video/mp4' : 'image/jpeg');
            },
            child: Text(
              attached
                  ? 'CHOOSE ANOTHER'
                  : 'CHOOSE ${isVideo ? 'CLIP' : 'PHOTO'}',
              style: GoogleFonts.spaceMono(
                fontWeight: FontWeight.bold,
                color: BrutalTheme.inkBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      key: const ValueKey('guest-note'),
      controller: _noteController,
      maxLines: 3,
      style: GoogleFonts.karla(fontSize: 14, color: BrutalTheme.inkBlack),
      decoration: InputDecoration(
        labelText: 'The lore',
        labelStyle: GoogleFonts.karla(
          fontSize: 12,
          color: BrutalTheme.graphite,
        ),
        hintText: 'Inside jokes, quotes, embarrassments…',
        hintStyle: GoogleFonts.karla(
          fontSize: 13,
          color: BrutalTheme.graphite.withOpacity(0.6),
        ),
        filled: true,
        fillColor: BrutalTheme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1D4B6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1D4B6)),
        ),
      ),
    );
  }

  Widget _buildCaptionField() {
    return TextField(
      key: const ValueKey('guest-caption'),
      controller: _captionController,
      style: GoogleFonts.karla(fontSize: 14, color: BrutalTheme.inkBlack),
      decoration: InputDecoration(
        labelText: 'Caption',
        labelStyle: GoogleFonts.karla(
          fontSize: 12,
          color: BrutalTheme.graphite,
        ),
        hintText: 'A line for the scrapbook…',
        hintStyle: GoogleFonts.karla(
          fontSize: 13,
          color: BrutalTheme.graphite.withOpacity(0.6),
        ),
        filled: true,
        fillColor: BrutalTheme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1D4B6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE1D4B6)),
        ),
      ),
    );
  }

  Widget _buildPlaceField() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        key: const ValueKey('guest-place'),
        controller: _placeController,
        style: GoogleFonts.karla(fontSize: 14, color: BrutalTheme.inkBlack),
        decoration: InputDecoration(
          labelText: 'Place (optional)',
          labelStyle: GoogleFonts.karla(
            fontSize: 12,
            color: BrutalTheme.graphite,
          ),
          hintText: 'e.g. the wrong hill, Sintra',
          hintStyle: GoogleFonts.karla(
            fontSize: 13,
            color: BrutalTheme.graphite.withOpacity(0.6),
          ),
          filled: true,
          fillColor: BrutalTheme.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1D4B6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1D4B6)),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            key: const ValueKey('guest-progress'),
            value: _progress,
            minHeight: 12,
            backgroundColor: const Color(0xFFE7DBC0),
            valueColor: const AlwaysStoppedAnimation<Color>(
              BrutalTheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Uploading… ${(_progress * 100).round()}%',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceMono(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: BrutalTheme.graphite,
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? BrutalTheme.primary : BrutalTheme.card,
            border: Border.all(
              color: active ? BrutalTheme.primary : const Color(0xFFE1D4B6),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? Colors.white : BrutalTheme.graphite,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : BrutalTheme.graphite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
