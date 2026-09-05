import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'models/trip_models.dart';
import 'services/session_ingestion_service.dart';
import 'screens/banger_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/create_trip_screen.dart';
import 'screens/invite_crew_screen.dart';
import 'screens/diary_tab.dart';
import 'screens/route_tab.dart';
import 'screens/add_memory_sheet.dart';

void main() {
  runApp(const RoadSongApp());
}

class RoadSongApp extends StatelessWidget {
  const RoadSongApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Road Song',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: BrutalTheme.backgroundLight,
        primaryColor: BrutalTheme.primary,
        useMaterial3: true,
      ),
      home: const OnboardingFlow(),
    );
  }
}

/// Entry flow: Welcome → Create Trip → Invite Crew → Main Shell.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({Key? key}) : super(key: key);

  @override
  _OnboardingFlowState createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const SessionIngestionService _service = SessionIngestionService();

  int _step = 0; // 0: welcome, 1: create, 2: invite, 3: main
  TripDraft _draft = const TripDraft();
  List<CrewMember> _crew = kDefaultCrew;
  final TripStore _tripStore = TripStore();

  void _goToCreate() => setState(() => _step = 1);

  void _goToInvite(TripDraft draft) {
    setState(() {
      _draft = draft;
      _step = 2;
    });
  }

  void _goToWelcome() => setState(() => _step = 0);

  void _goToCreateFromInvite() => setState(() => _step = 1);

  void _openDiary(TripDraft draft, List<CrewMember> crew) {
    final trip = Trip(
      id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
      name: draft.name,
      firstDay: draft.firstDay,
      lastDay: draft.lastDay,
      coverIndex: draft.coverIndex,
      crew: crew.where((m) => m.invited).toList(),
      sessionLink: _service.buildSessionLink(draft.name),
      createdAt: DateTime.now(),
    );
    _tripStore.addTrip(trip);
    setState(() {
      _draft = draft;
      _crew = crew;
      _step = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case 1:
        return CreateTripScreen(
          onBack: _goToWelcome,
          onContinue: _goToInvite,
          initialDraft: _draft,
        );
      case 2:
        return InviteCrewScreen(
          onBack: _goToCreateFromInvite,
          draft: _draft,
          initialCrew: _crew,
          onOpenDiary: _openDiary,
        );
      case 3:
        return MainShell(tripStore: _tripStore);
      default:
        return WelcomeScreen(onStart: _goToCreate);
    }
  }
}

/// The trip home hub: Diary / Route / Song tab browsing foundation.
class MainShell extends StatefulWidget {
  final TripStore? tripStore;

  const MainShell({Key? key, this.tripStore}) : super(key: key);

  @override
  _MainShellState createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _diaryIndex = 0;
  static const int _routeIndex = 1;
  static const int _songIndex = 2;

  static const Map<String, String> _demoTripDateRanges = {
    "Cabo Fail '23": 'JAN 7 – JAN 12',
    "Mudfest 2024": 'MAR 22 – MAR 24',
    "Vegas Mistakes": 'JUL 4 – JUL 7',
    "Roadtrip '22": 'AUG 10 – AUG 17',
  };

  /// Demo trips browseable before/alongside user-created trips.
  static const List<String> _demoTripNames = [
    "Cabo Fail '23",
    "Mudfest 2024",
    "Vegas Mistakes",
    "Roadtrip '22",
  ];

  static const Map<String, String> _tripLyrics = {
    "Cabo Fail '23": "Oh Cabo, you absolute disaster\n"
        "Spinning out, losing control much faster\n"
        "Sunburns, lost phones, and a broken toe\n"
        "Best worst trip we'll ever know!",
    "Mudfest 2024": "Stuck in the swamp, up to our knees\n"
        "Mosquito bites and a muddy breeze\n"
        "Lost my boot in the deep brown goo\n"
        "But hey at least I was here with you!",
    "Vegas Mistakes": "Vegas nights and neon lights\n"
        "Lost our wallets, got in fights\n"
        "Sleeping in the lobby chairs\n"
        "Nobody knows and nobody cares!",
    "Roadtrip '22": "Cruising down the highway line\n"
        "Flat tire number three is fine\n"
        "Radio only plays one song\n"
        "Singing it together all day long!"
  };

  int _currentTab = _diaryIndex;
  String _selectedTripName = _demoTripNames.first;

  final Map<String, List<TimelineMemory>> _tripMemories = {
    "Cabo Fail '23": const [
      TimelineMemory(
        id: 'mem-1',
        time: '11:42 PM',
        author: '@alex',
        text: 'Alex tried to fight a seagull for the last churro. The seagull won. We are never returning to this pier.',
        day: 1,
        dayDate: 'JAN 7',
        locationName: 'Marina Pier',
        latitude: 22.8892,
        longitude: -109.9112,
        likes: 12,
        likedByMe: false,
        rotationDegrees: -2.0,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAqb6LbvBrW4Ue7MDpYvmzbpa3X5fcuFWPtqqrdKEiPjauXeqmVkyr1FoK2oQ86wIllp4eCLovXTDALySIyfTpuZsJKZIffX3GI4Wc4TVJgzAzWHsgNsxwMe0EDW12vTKwjH7Yo4x8epfn-t-uF4ABXKVfuhM5rJfJlCtfFIEhuWowtu075ufdeINuDczymoFN2gb7MNlwvSI5oSPkGiqsrI2KtTxhp16JhKwgBpo32ItQuvg_DLFOLCd8W8UsZtYnNhDrM9QUFG3k',
        photoCaption: 'the churro incident',
      ),
      TimelineMemory(
        id: 'mem-2',
        time: '02:15 AM',
        author: '@sarah',
        text: 'Ended up at a 24hr laundromat playing poker with candy wrappers.',
        day: 1,
        dayDate: 'JAN 7',
        locationName: 'The 24hr Laundromat',
        latitude: 22.889,
        longitude: -109.916,
        likes: 8,
        likedByMe: true,
        rotationDegrees: 3.0,
      ),
      TimelineMemory(
        id: 'mem-3',
        time: '04:00 AM',
        author: '@group',
        text: 'Karaoke meltdown. We owe the owner an apology for destroying \'Mr. Brightside\'.',
        day: 2,
        dayDate: 'JAN 8',
        locationName: 'Karaoke Den',
        latitude: 22.8895,
        longitude: -109.913,
        likes: 15,
        likedByMe: false,
        rotationDegrees: -1.0,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAa9qiUmdAn3I64gl8K4ttDZttAwinQPlReLQZWN9kOMrbJVmCHh3RgR-xZU-4fr8CvUS5rD-ql8B8PB5XsPNnvYyZ0v00_KrlexLnLexSB_PqIX9f-lAE3tIeMZ5ijH95a1ALJfNJs-U9uEF6_kifH_8ISG6yah6Weuq6w1FO0TjnjW4VjGyIuTvrzvK6oVBs89ft5wtKJ4Cpx_SnJ4am_Tpb7T04QTErssDV2CC1yErbuA8DzUUFDrPuAefpcL8fRWO70WCXwDtM',
        photoCaption: 'mr. brightside, destroyed',
      ),
    ],
    "Mudfest 2024": const [
      TimelineMemory(
        id: 'mem-mud-1',
        time: '10:30 AM',
        author: '@dave',
        text: 'Truck got stuck in the first mud pit. Had to pay a tractor driver 50 bucks to pull us out.',
        day: 1,
        dayDate: 'MAR 22',
        locationName: 'The First Mud Pit',
        likes: 6,
        likedByMe: false,
        rotationDegrees: 1.5,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCc1O6C08mrvt95HE72xNmasi9USWsLzudZ6cJ4daYEzP00r8WZyGTGOswVy5Rp9NOQYdCSUUiEPWxlXt12mS04t5KpWceFiA3tsou2zx8WgajfsEoQLFFQ7gBifUslUPasmMiRVyGfl4AckykcHEIjcWD4KXEF6OZbVdeP37vb2tbvRysbSyZLe3zy4sXMcMBYxgihyzGBswCogeH3aDyclR0AGtWq1E9C7KwCf1dzoC7oNbd0oTDywqP-c6-BQF-_TsvL56eBePg',
        photoCaption: r'the $50 tractor',
      ),
      TimelineMemory(
        id: 'mem-mud-2',
        time: '02:00 PM',
        author: '@alex',
        text: 'Dropped the car keys in the mud. Spent 3 hours wading around with a metal detector.',
        day: 1,
        dayDate: 'MAR 22',
        locationName: 'Mud Pit #2 (Deeper)',
        likes: 4,
        likedByMe: true,
        rotationDegrees: -2.5,
      ),
    ],
    "Vegas Mistakes": const [
      TimelineMemory(
        id: 'mem-veg-1',
        time: '09:00 PM',
        author: '@alex',
        text: 'Put everything on red. It landed on black. Classic.',
        day: 1,
        dayDate: 'JUL 4',
        locationName: 'The Roulette Table, Caesars',
        latitude: 36.1162,
        longitude: -115.1747,
        likes: 11,
        likedByMe: false,
        rotationDegrees: -2.0,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDzHiCujisdOlw0WKq1uRsTgRBI7Bla5tbL5tCLeiXv4PjEvhoa8Gphpzscsi-x9vRLdn_YoyrtRUxU2I5429zUug0ql1BlvuSbrhaN0vGIx5EIBu9lshCzSm0Z-jSJOCTc-uNprN6YUHjd2MxNa8URbJFsP8wE594vcUtCwk7LHvHYCTOtSNivNEnz14ecHC2RZ3PjgY_hG4t3TLKeOMA2PpbQcD13c3DrbAki8n2JW3w0mHyaeuampdYbAQbZRw3HPUnA-EmDoPw',
        photoCaption: 'everything on red',
      ),
      TimelineMemory(
        id: 'mem-veg-2',
        time: '01:30 AM',
        author: '@sarah',
        text: 'Lost our shoes at a pool party. Had to walk back to the hotel on scorching concrete.',
        day: 2,
        dayDate: 'JUL 5',
        locationName: 'The Pool Party',
        latitude: 36.1173,
        longitude: -115.177,
        likes: 7,
        likedByMe: true,
        rotationDegrees: 1.5,
      ),
    ],
    "Roadtrip '22": const [
      TimelineMemory(
        id: 'mem-road-1',
        time: '01:00 PM',
        author: '@dave',
        text: 'Engine overheated in the middle of Death Valley. No cell service. Thankfully we had warm sodas.',
        day: 1,
        dayDate: 'AUG 10',
        locationName: 'Death Valley, Mile 42',
        latitude: 36.505,
        longitude: -117.0793,
        likes: 9,
        likedByMe: false,
        rotationDegrees: -1.5,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAg4EL78LnsYim1e5WkEBdzrj5BYFmyGTcTAttZCyyCXpya9F5BG1lA1jjLapZ-p4r4t8KI7lzb8SWGhVTDxEWbceYSeaYBqa0dyaan99fWy1NXXPC8rt_tw_-VpHz5syTQlJfIW5n4mAHV_rqear_-gVqwSgLlAnRD0A03gT-dJDTy8h2-duxFnTWcLIh6PrblLa7ehWdrR1HzQHTOkiKm3rSuzGL-2Mf7VCirqX-kATvRQl2CSeMdaokhtejeM-j9NmXmk70ES8g',
        photoCaption: 'warm sodas, zero cell service',
      ),
      TimelineMemory(
        id: 'mem-road-2',
        time: '05:30 PM',
        author: '@alex',
        text: 'Stumbled upon a museum of giant concrete dinosaurs. Best 5 dollars ever spent.',
        day: 1,
        dayDate: 'AUG 10',
        locationName: 'The Cabazon Dinosaurs',
        latitude: 33.9202,
        longitude: -116.5699,
        likes: 5,
        likedByMe: true,
        rotationDegrees: 2.0,
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    // Land on the most recently created trip when arriving from onboarding.
    final List<Trip> trips = widget.tripStore?.trips ?? const [];
    if (trips.isNotEmpty) {
      _selectedTripName = trips.last.name;
    }
  }

  List<Trip> get _createdTrips => widget.tripStore?.trips ?? const [];

  List<String> get _allTripNames => [
        for (final Trip trip in _createdTrips.reversed) trip.name,
        ..._demoTripNames,
      ];

  String? get _activeDateRange {
    for (final Trip trip in _createdTrips) {
      if (trip.name != _selectedTripName) continue;
      final String range = trip.dateRange.trim();
      if (range.isEmpty || range == '–') return null;
      return trip.dateRange;
    }
    return _demoTripDateRanges[_selectedTripName];
  }

  List<TimelineMemory> get _activeMemories =>
      _tripMemories[_selectedTripName] ?? const [];

  void _addMemory(TimelineMemory memory) {
    setState(() {
      _tripMemories.putIfAbsent(_selectedTripName, () => []).add(memory);
    });
  }

  void _navigateToTab(int index) {
    setState(() => _currentTab = index);
  }

  void _switchTrip(String name) {
    setState(() {
      _selectedTripName = name;
      _currentTab = _diaryIndex;
    });
  }

  void _showTripPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _TripPickerSheet(
          trips: _allTripNames,
          selectedTrip: _selectedTripName,
          dateRangeFor: (String name) {
            for (final Trip trip in _createdTrips) {
              if (trip.name == name) return trip.dateRange;
            }
            return _demoTripDateRanges[name];
          },
          onSelect: (String name) {
            Navigator.of(sheetContext).pop();
            _switchTrip(name);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<TimelineMemory> memories = _activeMemories;
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: IndexedStack(
        index: _currentTab,
        children: [
          DiaryTab(
            tripName: _selectedTripName,
            tripDateRange: _activeDateRange,
            memories: memories,
            onAddMemory: _addMemory,
            onOpenSong: () => _navigateToTab(_songIndex),
            onSwitchTrip: _showTripPicker,
            pickPhotoBytes: pickPhotoFromGallery,
          ),
          RouteTab(
            tripName: _selectedTripName,
            memories: memories,
            onOpenDiary: () => _navigateToTab(_diaryIndex),
          ),
          BangerScreen(
            onBack: () => _navigateToTab(_diaryIndex),
            tripName: _selectedTripName,
            lyrics: _tripLyrics[_selectedTripName] ?? '',
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: BrutalTheme.paper2,
          border: Border(
            top: BorderSide(color: Color(0xFFE7DBC0), width: 1.0),
          ),
        ),
        padding: const EdgeInsets.only(
          bottom: 12.0,
          top: 8.0,
          left: 16.0,
          right: 16.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(
              index: _diaryIndex,
              icon: Icons.edit_note,
              label: 'Diary',
            ),
            _buildBottomNavItem(
              index: _routeIndex,
              icon: Icons.flag,
              label: 'Route',
            ),
            _buildBottomNavItem(
              index: _songIndex,
              icon: Icons.music_note,
              label: 'Song',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isActive = _currentTab == index;
    final Color itemColor = isActive ? BrutalTheme.primary : BrutalTheme.graphite;

    return GestureDetector(
      onTap: () => _navigateToTab(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: itemColor),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: itemColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing every demo + created trip to switch the active trip.
class _TripPickerSheet extends StatelessWidget {
  final List<String> trips;
  final String selectedTrip;
  final String? Function(String name) dateRangeFor;
  final ValueChanged<String> onSelect;

  const _TripPickerSheet({
    required this.trips,
    required this.selectedTrip,
    required this.dateRangeFor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 34),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Open a trip',
                style: GoogleFonts.caveat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: BrutalTheme.inkBlack,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final String name in trips)
                    _TripRow(
                      name: name,
                      dateRange: dateRangeFor(name),
                      active: name == selectedTrip,
                      onTap: () => onSelect(name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final String name;
  final String? dateRange;
  final bool active;
  final VoidCallback onTap;

  const _TripRow({
    required this.name,
    required this.dateRange,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('trip-row-$name'),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? BrutalTheme.yellow : BrutalTheme.card,
          border: Border.all(
            color: active ? BrutalTheme.primary : const Color(0xFFEBDFC6),
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.toUpperCase(),
                    style: GoogleFonts.instrumentSerif(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: BrutalTheme.inkBlack,
                    ),
                  ),
                  if (dateRange != null)
                    Text(
                      dateRange!,
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        color: BrutalTheme.graphite,
                      ),
                    ),
                ],
              ),
            ),
            if (active)
              const Icon(
                Icons.check_circle,
                color: BrutalTheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
