import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/trip_models.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

class EvidenceScreen extends StatefulWidget {
  final VoidCallback onBack;
  final String tripName;
  final String mapImageUrl;
  final List<TimelineMemory> memories;
  final List<MapPin> mapPins;
  final ValueChanged<TimelineMemory> onAddMemory;

  const EvidenceScreen({
    Key? key,
    required this.onBack,
    required this.tripName,
    required this.mapImageUrl,
    required this.memories,
    required this.mapPins,
    required this.onAddMemory,
  }) : super(key: key);

  @override
  _EvidenceScreenState createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  final ScrollController _scrollController = ScrollController();
  
  // Highlight states
  String? _highlightedId;

  void _scrollToMemory(String id, double offset) {
    setState(() {
      _highlightedId = id;
    });

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );

    // Clear highlight after flash
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _highlightedId = null;
        });
      }
    });
  }

  void _showAddTeaDialog(BuildContext context) {
    final TextEditingController authorController = TextEditingController(text: '@alex');
    final TextEditingController textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: BrutalCard(
              color: BrutalTheme.card,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DymoLabel(text: 'ADD NEW EVIDENCE', fontSize: 16),
                  const SizedBox(height: 16),
                  Text(
                    'Spill the tea. Document what happened.',
                    style: GoogleFonts.karla(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Author Input
                  Text(
                    'YOUR HANDLE:',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BrutalTheme.brutalDecoration(
                      color: Colors.white,
                      borderWidth: 1.0,
                      showShadow: false,
                    ),
                    child: TextField(
                      controller: authorController,
                      style: GoogleFonts.karla(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: BrutalTheme.inkBlack,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Memory Text Input
                  Text(
                    'WHAT HAPPENED:',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BrutalTheme.brutalDecoration(
                      color: Colors.white,
                      borderWidth: 1.0,
                      showShadow: false,
                    ),
                    child: TextField(
                      controller: textController,
                      maxLines: 3,
                      style: GoogleFonts.karla(
                        fontSize: 14,
                        color: BrutalTheme.inkBlack,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: 'e.g. Lost a shoe in the river...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: BrutalButton(
                          color: BrutalTheme.primary,
                          onPressed: () {
                            if (textController.text.trim().isEmpty) return;
                            
                            // Format current time
                            final now = DateTime.now();
                            final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
                            final timeString = "${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
                            
                            final newMemory = TimelineMemory(
                              id: 'mem-${DateTime.now().millisecondsSinceEpoch}',
                              time: timeString,
                              author: authorController.text.trim().startsWith('@') 
                                  ? authorController.text.trim() 
                                  : '@${authorController.text.trim()}',
                              text: textController.text.trim(),
                              icon: Icons.error_outline,
                              iconBg: BrutalTheme.yellow,
                              category: 'TEA',
                              rotationDegrees: (math.Random().nextDouble() * 6) - 3,
                            );
                            
                            widget.onAddMemory(newMemory);
                            Navigator.pop(context);
                          },
                          child: Text(
                            'SPILL IT',
                            style: GoogleFonts.karla(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BrutalButton(
                          color: BrutalTheme.yellow,
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.karla(
                              color: BrutalTheme.inkBlack,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66.0),
        child: Container(
          decoration: const BoxDecoration(
            color: BrutalTheme.paper2,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE7DBC0), width: 1.0),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: BrutalTheme.inkBlack,
                        size: 24,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "${widget.tripName.toUpperCase()} EVIDENCE",
                        style: GoogleFonts.instrumentSerif(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: BrutalTheme.inkBlack,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        ),
      ),
      body: GrainOverlay(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Map section (approx 35% height)
                _buildMapSection(),
                // Bottom timeline section (approx 65% height)
                Expanded(
                  child: _buildTimelineSection(),
                ),
              ],
            ),
            
            // Sticky bottom CTA banner
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: BrutalButton(
                color: BrutalTheme.primary,
                fullWidth: true,
                height: 56.0,
                onPressed: () => _showAddTeaDialog(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_box, color: Colors.white, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'ADD THE TEA',
                      style: GoogleFonts.karla(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 240,
      decoration: const BoxDecoration(
        color: Colors.grey,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE7DBC0), width: 1.0),
        ),
        image: DecorationImage(
          image: NetworkImage(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuCc1O6C08mrvt95HE72xNmasi9USWsLzudZ6cJ4daYEzP00r8WZyGTGOswVy5Rp9NOQYdCSUUiEPWxlXt12mS04t5KpWceFiA3tsou2zx8WgajfsEoQLFFQ7gBifUslUPasmMiRVyGfl4AckykcHEIjcWD4KXEF6OZbVdeP37vb2tbvRysbSyZLe3zy4sXMcMBYxgihyzGBswCogeH3aDyclR0AGtWq1E9C7KwCf1dzoC7oNbd0oTDywqP-c6-BQF-_TsvL56eBePg',
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black26, BlendMode.multiply),
        ),
      ),
      child: Stack(
        children: [
          Container(color: Colors.black12),
          ...widget.mapPins.map((pin) {
            final index = widget.memories.indexWhere((m) => m.id == pin.memoryId);
            final double targetScrollOffset = index >= 0 ? index * 260.0 : 0.0;

            return Positioned(
              left: pin.left,
              top: pin.top,
              right: pin.right,
              bottom: pin.bottom,
              child: GestureDetector(
                onTap: () => _scrollToMemory(pin.memoryId, targetScrollOffset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: -3.0 * 3.14159 / 180,
                      child: Container(
                        decoration: BrutalTheme.brutalDecoration(
                          color: BrutalTheme.primary,
                          borderWidth: 1.0,
                          showShadow: true,
                          shadowOffset: const Offset(1, 2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Text(
                          pin.label.toUpperCase(),
                          style: GoogleFonts.karla(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.location_on,
                      color: BrutalTheme.primary,
                      size: 36,
                      shadows: [
                        Shadow(
                          color: Color(0x66433729),
                          offset: Offset(1, 2),
                          blurRadius: 4.0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Stack(
      children: [
        // Vertical Timeline Track Line
        Positioned(
          left: 36,
          top: 0,
          bottom: 0,
          child: Container(
            width: 2,
            color: const Color(0xFFE7DBC0),
          ),
        ),
        
        SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 120.0),
          child: Column(
            children: [
              ...widget.memories.map((memory) {
                final bool isHighlighted = _highlightedId == memory.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: _buildTimelineNode(
                    id: memory.id,
                    time: memory.time,
                    author: memory.author,
                    rotationDegrees: memory.rotationDegrees,
                    flash: isHighlighted,
                    icon: memory.icon,
                    iconBg: memory.iconBg,
                    iconColor: memory.iconColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (memory.imageUrl != null)
                          Container(
                            height: 120,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                              image: DecorationImage(
                                image: NetworkImage(memory.imageUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        if (memory.category != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: memory.iconBg,
                              border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              memory.category!.toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: memory.iconColor,
                              ),
                            ),
                          ),
                        Text(
                          memory.text,
                          style: GoogleFonts.karla(
                            fontSize: 14.5,
                            height: 1.45,
                            color: BrutalTheme.inkBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 10),
              Text(
                '--- END OF SCRAPBOOK ---',
                style: GoogleFonts.spaceMono(
                  color: BrutalTheme.graphite,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineNode({
    required String id,
    required String time,
    required String author,
    required Widget child,
    required IconData icon,
    required Color iconBg,
    Color iconColor = BrutalTheme.inkBlack,
    double rotationDegrees = 0.0,
    bool flash = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline node indicator circle
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 8.0, top: 12.0),
          decoration: BrutalTheme.brutalDecoration(
            color: iconBg,
            borderWidth: 1.0,
            showShadow: true,
            shadowOffset: const Offset(1, 2),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 16),
        // Card content
        Expanded(
          child: BrutalCard(
            color: flash ? BrutalTheme.yellow : BrutalTheme.card,
            rotationDegrees: rotationDegrees,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 6),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFE7DBC0),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        time,
                        style: GoogleFonts.spaceMono(
                          color: BrutalTheme.graphite,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        author,
                        style: GoogleFonts.caveat(
                          color: BrutalTheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
