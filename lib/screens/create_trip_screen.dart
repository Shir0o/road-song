import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/trip_models.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

/// Cover swatch options for a new trip's scrapbook cover.
const List<Color> kCoverSwatches = [
  Color(0xFFC05B3E),
  Color(0xFF3E6B8A),
  Color(0xFF7D8663),
  Color(0xFFB08A3E),
  Color(0xFFA5586B),
];

/// Screen for entering a custom trip name, date range, and cover swatch.
class CreateTripScreen extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<TripDraft> onContinue;
  final TripDraft initialDraft;

  const CreateTripScreen({
    Key? key,
    required this.onBack,
    required this.onContinue,
    this.initialDraft = const TripDraft(),
  }) : super(key: key);

  @override
  _CreateTripScreenState createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _firstDayController;
  late final TextEditingController _lastDayController;
  late int _coverIndex;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDraft.name);
    _firstDayController = TextEditingController(
      text: widget.initialDraft.firstDay,
    );
    _lastDayController = TextEditingController(
      text: widget.initialDraft.lastDay,
    );
    _coverIndex = widget.initialDraft.coverIndex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firstDayController.dispose();
    _lastDayController.dispose();
    super.dispose();
  }

  void _continue() {
    final draft = TripDraft(
      name: _nameController.text.trim(),
      firstDay: _firstDayController.text.trim(),
      lastDay: _lastDayController.text.trim(),
      coverIndex: _coverIndex,
    );
    widget.onContinue(draft);
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
          color: BrutalTheme.graphite,
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, {String? hintText}) {
    return Container(
      decoration: BrutalTheme.brutalDecoration(
        color: BrutalTheme.card,
        borderWidth: 1.0,
        showShadow: false,
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.karla(fontSize: 15, color: BrutalTheme.inkBlack),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          hintText: hintText,
          hintStyle: GoogleFonts.karla(
            color: BrutalTheme.graphite.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 46),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Text(
                  '← Back',
                  style: GoogleFonts.karla(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'New trip',
                style: GoogleFonts.instrumentSerif(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: BrutalTheme.inkBlack,
                ),
              ),
              Transform.rotate(
                angle: -2 * 3.14159 / 180,
                child: Text(
                  'where did the road take you?',
                  style: GoogleFonts.caveat(
                    fontSize: 20,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _fieldLabel('TRIP NAME'),
              _textField(_nameController, hintText: 'Lisbon → Porto'),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('FIRST DAY'),
                        _textField(_firstDayController),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('LAST DAY'),
                        _textField(_lastDayController),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _fieldLabel('SCRAPBOOK COVER'),
              const SizedBox(height: 8),
              Row(
                children: List.generate(kCoverSwatches.length, (index) {
                  final bool selected = index == _coverIndex;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        key: ValueKey('cover-$index'),
                        onTap: () => setState(() => _coverIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 66,
                          decoration: BoxDecoration(
                            color: kCoverSwatches[index],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? BrutalTheme.inkBlack
                                  : const Color(0xFFE1D4B6),
                              width: selected ? 3 : 1,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 22,
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: BrutalButton(
                  onPressed: _continue,
                  child: Text(
                    'CONTINUE',
                    style: GoogleFonts.spaceMono(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
