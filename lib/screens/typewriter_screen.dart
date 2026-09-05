import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_models.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

class TypewriterScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onProduceTrack;
  final String tripName;
  final String initialLyrics;
  final List<TimelineMemory> memories;
  final ValueChanged<String> onLyricsUpdated;

  const TypewriterScreen({
    Key? key,
    required this.onBack,
    required this.onProduceTrack,
    required this.tripName,
    required this.initialLyrics,
    required this.memories,
    required this.onLyricsUpdated,
  }) : super(key: key);

  @override
  _TypewriterScreenState createState() => _TypewriterScreenState();
}

class _TypewriterScreenState extends State<TypewriterScreen> {
  // Animation states
  bool _isGenerating = false;
  double _noteScale = 1.0;
  double _noteOpacity = 1.0;
  Offset _noteOffset = Offset.zero;
  
  // Typewriter text state
  int _charCount = 0;
  String? _generatedLyrics;
  String get _targetText => _generatedLyrics ?? widget.initialLyrics;
      
  Timer? _typewriterTimer;

  // API settings state
  String _apiKey = '';
  String _selectedModel = 'claude-3-5-sonnet-latest';
  String? _errorMessage;

  String get _note1Text {
    if (widget.tripName == "Mudfest 2024") return '"Waded in mud for hours!"\n- Alex';
    if (widget.tripName == "Vegas Mistakes") return '"Lost all my cash!"\n- Alex';
    if (widget.tripName == "Roadtrip '22") return '"No AC in Death Valley!"\n- Dave';
    return '"I lost my shoe in the ocean!"\n- Sarah';
  }

  String get _note2Text {
    if (widget.tripName == "Mudfest 2024") return 'Pin:\nThe giant mud slide';
    if (widget.tripName == "Vegas Mistakes") return 'Pin:\nThe Elvis chapel';
    if (widget.tripName == "Roadtrip '22") return 'Pin:\nConcrete dinosaur';
    return 'Pin:\nThe sketchy taco stand';
  }

  String get _note3Text {
    if (widget.tripName == "Mudfest 2024") return 'Dave slept on hay';
    if (widget.tripName == "Vegas Mistakes") return 'Flamingo in pool';
    if (widget.tripName == "Roadtrip '22") return 'Cassette player jammed';
    return 'Dave dropped his taco';
  }

  String get _note3Author {
    if (widget.tripName == "Vegas Mistakes") return 'Sarah';
    if (widget.tripName == "Roadtrip '22") return 'Alex';
    return 'Dave';
  }

  String _getVerse1TextForTrip(String tripName) {
    if (tripName == "Mudfest 2024") {
      return "Truck got stuck in the first mud pit\n"
          "Dave was not happy about it one bit\n"
          "Wading in brown sludge up to our waist\n"
          "Funnel cake crumbs and a swampy taste";
    } else if (tripName == "Vegas Mistakes") {
      return "Put all our chips on a single spin\n"
          "Thought for sure we were gonna win\n"
          "Lost every dollar by half past nine\n"
          "Sarah fell asleep by the neon sign";
    } else if (tripName == "Roadtrip '22") {
      return "Drove ten hours in the blazing sun\n"
          "Flat tire number three was so much fun\n"
          "No AC and the soda was warm\n"
          "Rolled into town in a desert storm";
    } else {
      return "Packed my bags, forgot my passport\n"
          "Dave threw up on the airport transport\n"
          "Tequila shots before the plane took flight\n"
          "Someone started a random fight";
    }
  }

  List<String> _getAvatarsForTrip(String tripName) {
    if (tripName == "Mudfest 2024") {
      return [
        'https://lh3.googleusercontent.com/aida-public/AB6AXuC8uhCZVdeFadbMnrz0wJV-brI8gekrKOtzAtT-jXMrbwzoTEcm5i85_8b8XT9wZMYt-6b4Cw_lAO9MPdqsQ3cwvkbjRQH4hzBuFB68H6lWLUNL8Wd7BpVim-3WNiFntmqrrPw2rHTRl4C4CxZ_-E4JUrrgTLN_adicfzDsi_KotyZl4-RFBfuvb7Jm24RuDctc7jz_a7G_AKGWS-HuhEzyHmvKz5R8zGiiI1iEx92CUuUILv6i6YboM04tCyJ3fjvFw3AIAB-HrGw',
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCU2_zmIFRpkgWusvXog_OeYiNfSq2E7F-mTgBQDSodDP0vEgCerFiVh6gd3cvq-N84urrif-UUq1mkMZUV4_A1PndsP8huReQvOedq3TCgLon5EZVKcPkk3y4mD_dd4734W7SqFM49a0HMUswKI04y4hwi0Fpw1R9Z2IvPE3RDoXFXn46i2mSCZ9uZOpkjKdngtudurEmy_0_bCSKxm9TV0_dYL9-GAvAmeVZRMi7U3FFtlvxWGlNpEdCShSh4KmtOPL6vJ9tIEFU'
      ];
    } else if (tripName == "Vegas Mistakes") {
      return [
        'https://lh3.googleusercontent.com/aida-public/AB6AXuD5_VCoHcnC1pLqMCyDVCqdL80braXgy_XDPAvqo1vPZzFWrf0oimhamj_541On7f3LvcP1fDoaDSH02AHKaWLu5ONF-u3Bwdi0lb6XmugL5xgACUWXEU3HMuc7qA6-Qunz-JKSrRJxboDK76UxKPRfulxHijcPJTlDlCJ6QeqhGccelZE1qZfQuNBRLVZZTelXauVNGsinMSa6Gb_mQ8SS8PkSGt9CUacivzeqY5qQLxJZIluwnzXunquaphS_iA5giN9cnQlVWv0',
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCghbkiryWQhllkb3HHw0EoxcfB-7EWQiMknmg3PbaUm3ONhic0-gmWdSo2UQ3b8NfhOisBharEcLXY9w9S97Cuj6Jz5rKfksZt8Le-HpOx37FOZ01gG19h-t8NKuFmSNP1hFg3edNKBbxCte9n-tsdM_WFVLJDZphFIKEwwXFoID0NQYcjVs2_2CiPpVd-R8HmnxRO78nrdnj_VkgBn5t0sSpNjBcM8feOz4HqV5jMZuTJ1zVFzoBZ_iAqnajoZXvMNtqBRSScElo'
      ];
    } else if (tripName == "Roadtrip '22") {
      return [
        'https://lh3.googleusercontent.com/aida-public/AB6AXuD5oayLuAuT-Jf8shcPbxOV0xGBf27cwpZVyFMJLCHGwGYNBp1-_V8Nyy_w1xGse8q0QauAG_uEL9uTT7FpyKWah6CQvZrBqEDrDyQqk8tkfVJb4XMN3I-7gkSGwy9_Cqz5t67P9ecpKVHnNPPpAR1AnIqfNv7e5hhi9Vm3hfKBNnewGKxbfksA-AricqPLxW8TqVOwiU8wUGV0BK1vU2ciA1TBZ2qtIg8r6EOj8S2wmNCxcDeVpbJGtMam3X2uHhL1QcXlDoTDtcs',
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDCp5yQe-WSHgb-VV-LU-_Bi8lOk9kPjwRsXpPLgAuye71CoV0qktKJl6mMVEljAKwAaSDccpL6-IDxNw9RC1aBajcsMXbAKEBxHXKAsgsPEz6f5Dlwxixk6fmN6gngiUkqqafauyoqTI6fqvXvte4i9EugxgwpDjVJMSVigfpkEEkyO-mCtE71ne4QUL1VdvbZ7_QOO-6-IWmyw7n83QYcwfAoyZYTTTfkYITI-Lu293g66d7knlhprRXXVJc8Ncskk34mCS0YrvA'
      ];
    } else {
      return [
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBaaTO7cLQFBrDukdQJfD3l7ZU6uEhLr7qQH9TyLcgNYThOs7L1vEfkg_UAYeznV4j9-TuRPuvNdEm-a8SRMfXKCouP4ktiKDDcSteE25_lXzgpKSK0ap500-fE4wOvwsjR7sPnnTbkc8-tlghvXVCjAwh9uMVjsdJcQmmUEBEgJ4mCl_lEt72jI-lgpitIkQzLHQq5irnwgSJ6lEpt1JUXp2CthNbiGI6ugpLlX-u9WonwX_UkMZN7MP8RJtCYp6KiE0phyGVbuwU',
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCghbkiryWQhllkb3HHw0EoxcfB-7EWQiMknmg3PbaUm3ONhic0-gmWdSo2UQ3b8NfhOisBharEcLXY9w9S97Cuj6Jz5rKfksZt8Le-HpOx37FOZ01gG19h-t8NKuFmSNP1hFg3edNKBbxCte9n-tsdM_WFVLJDZphFIKEwwXFoID0NQYcjVs2_2CiPpVd-R8HmnxRO78nrdnj_VkgBn5t0sSpNjBcM8feOz4HqV5jMZuTJ1zVFzoBZ_iAqnajoZXvMNtqBRSScElo'
      ];
    }
  }  @override
  void initState() {
    super.initState();
    _charCount = widget.initialLyrics.isNotEmpty ? widget.initialLyrics.length : 0;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _apiKey = prefs.getString('claude_api_key') ?? '';
        _selectedModel = prefs.getString('claude_selected_model') ?? 'claude-3-5-sonnet-latest';
      });
    } catch (_) {}
  }

  Future<void> _saveSettings(String key, String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('claude_api_key', key);
      await prefs.setString('claude_selected_model', model);
      setState(() {
        _apiKey = key;
        _selectedModel = model;
      });
    } catch (_) {}
  }

  void _showSettingsDialog() {
    final keyController = TextEditingController(text: _apiKey);
    String tempModel = _selectedModel;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: BrutalCard(
                color: BrutalTheme.backgroundLight,
                borderWidth: 4.0,
                showShadow: true,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CLAUDE API SETTINGS',
                      style: GoogleFonts.spaceMono(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: BrutalTheme.inkBlack,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'API KEY',
                      style: GoogleFonts.spaceMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: BrutalTheme.graphite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BrutalTheme.brutalDecoration(
                        color: Colors.white,
                        borderWidth: 2.0,
                        showShadow: false,
                      ),
                      child: TextField(
                        controller: keyController,
                        obscureText: true,
                        style: GoogleFonts.spaceMono(
                          fontSize: 14,
                          color: BrutalTheme.inkBlack,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          hintText: 'sk-ant-api03-...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MODEL',
                      style: GoogleFonts.spaceMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: BrutalTheme.graphite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BrutalTheme.brutalDecoration(
                        color: Colors.white,
                        borderWidth: 2.0,
                        showShadow: false,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: tempModel,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: GoogleFonts.spaceMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: BrutalTheme.inkBlack,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setDialogState(() {
                                tempModel = newValue;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'claude-3-5-sonnet-latest',
                              child: Text('Claude 3.5 Sonnet (Default)'),
                            ),
                            DropdownMenuItem(
                              value: 'claude-3-5-haiku-latest',
                              child: Text('Claude 3.5 Haiku'),
                            ),
                            DropdownMenuItem(
                              value: 'claude-3-opus-latest',
                              child: Text('Claude 3 Opus'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: BrutalButton(
                            color: Colors.white,
                            height: 44,
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'CANCEL',
                              style: GoogleFonts.spaceMono(
                                fontWeight: FontWeight.bold,
                                color: BrutalTheme.inkBlack,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BrutalButton(
                            color: BrutalTheme.primary,
                            height: 44,
                            onPressed: () {
                              _saveSettings(keyController.text.trim(), tempModel);
                              Navigator.pop(context);
                            },
                            child: Text(
                              'SAVE',
                              style: GoogleFonts.spaceMono(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateLyricsWithClaude() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _noteScale = 0.1;
      _noteOpacity = 0.0;
      _noteOffset = const Offset(120.0, -180.0);
    });

    _charCount = 0;
    _typewriterTimer?.cancel();

    // Prepare prompt
    final memoriesText = widget.memories.isEmpty
        ? "No specific memories documented yet. Write lyrics based on the spirit of the trip name."
        : widget.memories.map((m) => "- ${m.author}: ${m.text}").join("\n");

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': _selectedModel,
          'max_tokens': 1024,
          'system': "You are an expert songwriter who writes catchy, high-energy travel song lyrics. You write short song segments (e.g. 4-6 lines) in response to trip descriptions and memories. Do not output any chat explanation, conversational filler, markdown formatting (like ```), or formatting notes. Only output the lyrics directly, separating lines with newlines.",
          'messages': [
            {
              'role': 'user',
              'content': "Write a verse or chorus for a song called 'Road Song'.\nTrip Name: ${widget.tripName}\nMemories:\n$memoriesText\n\nGenerate a short, energetic, and humorous lyrics block (4 to 8 lines) that references these memories."
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String rawText = data['content'][0]['text'] as String;
        // Clean any accidental markdown format tags
        final cleanText = rawText.replaceAll(RegExp(r'^```\w*\n?'), '').replaceAll(RegExp(r'\n?```$'), '').trim();

        setState(() {
          _generatedLyrics = cleanText;
        });

        // Trigger typewriter animation
        _startTypewriterAnimation();
      } else {
        final errorBody = response.body;
        String friendlyError = "API Error (${response.statusCode})";
        try {
          final errorData = jsonDecode(errorBody);
          friendlyError = errorData['error']['message'] ?? friendlyError;
        } catch (_) {}
        setState(() {
          _isGenerating = false;
          _errorMessage = friendlyError;
        });
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = "Network connection failed. Please check your internet connection.";
      });
    }
  }

  void _startGeneration() {
    if (_isGenerating) return;
    
    if (_apiKey.isEmpty) {
      _showOfflineNotification();
      _startMockGeneration();
    } else {
      _generateLyricsWithClaude();
    }
  }

  void _showOfflineNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BrutalTheme.yellow,
        content: Text(
          "Using mock generation. Configure Claude API key in Settings (cyan gear) for AI lyrics!",
          style: GoogleFonts.spaceMono(
            color: BrutalTheme.inkBlack,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _startMockGeneration() {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedLyrics = null; // Revert to initialLyrics/fallback
      _noteScale = 0.1;
      _noteOpacity = 0.0;
      _noteOffset = const Offset(120.0, -180.0);
    });

    _charCount = 0;
    _typewriterTimer?.cancel();
    
    _startTypewriterAnimation();
  }

  void _startTypewriterAnimation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      _typewriterTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
        if (_charCount < _targetText.length) {
          setState(() {
            _charCount++;
          });
        } else {
          timer.cancel();
          setState(() {
            _isGenerating = false;
          });
          widget.onLyricsUpdated(_targetText);
        }
      });
    });
  }
  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatars = _getAvatarsForTrip(widget.tripName);
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
                      decoration: BrutalTheme.brutalDecoration(
                        color: BrutalTheme.yellow,
                        borderWidth: 1.0,
                        showShadow: true,
                        shadowOffset: const Offset(1, 2),
                      ),
                      child: const Icon(Icons.arrow_back, color: BrutalTheme.inkBlack),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showSettingsDialog,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BrutalTheme.brutalDecoration(
                        color: BrutalTheme.cyan,
                        borderWidth: 1.0,
                        showShadow: true,
                        shadowOffset: const Offset(1, 2),
                      ),
                      child: const Icon(Icons.settings, color: BrutalTheme.inkBlack),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.tripName.toUpperCase(),
                        style: GoogleFonts.instrumentSerif(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: BrutalTheme.inkBlack,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                          image: DecorationImage(
                            image: NetworkImage(avatars[0]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                          image: DecorationImage(
                            image: NetworkImage(avatars[1]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: GrainOverlay(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 76.0, bottom: 200.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVerse1Block(),
                  const SizedBox(height: 16),
                  _buildErrorBlock(),
                  _buildChorusBlock(),
                  const SizedBox(height: 16),
                  _buildVerse2EmptyBlock(),
                ],
              ),
            ),
            
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: BrutalTheme.backgroundLight.withOpacity(0.9),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE7DBC0), width: 1.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildToolbarBtn("[B]"),
                    const SizedBox(width: 8),
                    _buildToolbarBtn("[I]"),
                    const SizedBox(width: 8),
                    _buildToolbarBtn("[LIST]", icon: Icons.format_list_bulleted),
                  ],
                ),
              ),
            ),
            
            Positioned(
              right: 12,
              top: 140,
              child: Opacity(
                opacity: 0.35,
                child: BrutalCard(
                  color: BrutalTheme.yellow,
                  rotationDegrees: 6.0,
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 100,
                    child: Text(
                      _note1Text,
                      style: GoogleFonts.caveat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: BrutalTheme.inkBlack,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            Positioned(
              left: 12,
              top: 360,
              child: Opacity(
                opacity: 0.35,
                child: BrutalCard(
                  color: BrutalTheme.card,
                  rotationDegrees: -12.0,
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 100,
                    child: Text(
                      _note2Text,
                      style: GoogleFonts.caveat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: BrutalTheme.inkBlack,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: BrutalTheme.paper2,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE7DBC0), width: 1.0),
                  ),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrutalButton(
                      color: BrutalTheme.primary,
                      fullWidth: true,
                      height: 56.0,
                      onPressed: _startGeneration,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _isGenerating ? 'GENERATING...' : 'GENERATE VERSE',
                            style: GoogleFonts.karla(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    BrutalButton(
                      color: BrutalTheme.yellow,
                      fullWidth: true,
                      height: 50.0,
                      onPressed: widget.onProduceTrack,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'PRODUCE TRACK',
                            style: GoogleFonts.karla(
                              color: BrutalTheme.inkBlack,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.album, color: BrutalTheme.inkBlack),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_noteOpacity > 0.01)
              Positioned(
                left: 20,
                bottom: 154,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInBack,
                  transform: Matrix4.translationValues(_noteOffset.dx, _noteOffset.dy, 0)
                    ..scale(_noteScale),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _noteOpacity,
                    child: Transform.rotate(
                      angle: -3.0 * 3.14159 / 180,
                      child: BrutalCard(
                        color: BrutalTheme.card,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sticky_note_2, size: 16, color: BrutalTheme.inkBlack),
                            const SizedBox(width: 6),
                            Text(
                              _note3Text,
                              style: GoogleFonts.caveat(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: BrutalTheme.inkBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarBtn(String label, {IconData? icon}) {
    return Container(
      decoration: BrutalTheme.brutalDecoration(
        color: Colors.white,
        borderWidth: 1.0,
        borderRadius: BorderRadius.circular(6.0),
        showShadow: false,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: icon != null 
        ? Icon(icon, size: 16, color: BrutalTheme.inkBlack)
        : Text(
            label,
            style: GoogleFonts.karla(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: BrutalTheme.inkBlack,
            ),
          ),
    );
  }

  Widget _buildVerse1Block() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent, width: 2.0),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "[VERSE 1]",
                style: GoogleFonts.spaceMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: BrutalTheme.graphite,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getVerse1TextForTrip(widget.tripName),
                style: GoogleFonts.instrumentSerif(
                  fontSize: 18,
                  height: 1.45,
                  color: BrutalTheme.inkBlack,
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 4,
            right: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: BrutalTheme.cyan,
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BrutalTheme.cyan,
                    border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    _note3Author,
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChorusBlock() {
    final bool showGeneratingHeader = _isGenerating && (_charCount < _targetText.length);
    final String currentRevealText = _targetText.substring(0, _charCount);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent, width: 2.0),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showGeneratingHeader ? "[CHORUS - GENERATING...]" : "[CHORUS]",
                style: GoogleFonts.spaceMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: showGeneratingHeader ? BrutalTheme.primary : BrutalTheme.graphite,
                ),
              ),
              const SizedBox(height: 8),
              if (_charCount > 0)
                Text(
                  currentRevealText,
                  style: GoogleFonts.instrumentSerif(
                    fontSize: 18,
                    height: 1.45,
                    color: BrutalTheme.inkBlack,
                  ),
                )
              else
                Text(
                  "...\n\n\n",
                  style: GoogleFonts.instrumentSerif(
                    fontSize: 18,
                    height: 1.45,
                    color: Colors.transparent,
                  ),
                ),
            ],
          ),
          if (showGeneratingHeader)
            Positioned(
              left: 120,
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 2,
                    height: 20,
                    color: BrutalTheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BrutalTheme.primary,
                      border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      'AI Magic',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerse2EmptyBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent, width: 2.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "[VERSE 2]",
            style: GoogleFonts.spaceMono(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: BrutalTheme.graphite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Type here or generate...",
            style: GoogleFonts.instrumentSerif(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: BrutalTheme.graphite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBlock() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: BrutalCard(
        color: const Color(0xFFFCD7D7), // Softer red highlight
        borderWidth: 1.0,
        showShadow: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: BrutalTheme.inkBlack),
                const SizedBox(width: 8),
                Text(
                  "GENERATION ERROR",
                  style: GoogleFonts.karla(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.karla(
                fontSize: 12,
                color: BrutalTheme.inkBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
