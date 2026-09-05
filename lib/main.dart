import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'models/trip_models.dart';
import 'services/session_ingestion_service.dart';
import 'screens/scrapbook_screen.dart';
import 'screens/typewriter_screen.dart';
import 'screens/evidence_screen.dart';
import 'screens/banger_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/create_trip_screen.dart';
import 'screens/invite_crew_screen.dart';
import 'widgets/brutal_widgets.dart';

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

class MainShell extends StatefulWidget {
  final TripStore? tripStore;

  const MainShell({Key? key, this.tripStore}) : super(key: key);

  @override
  _MainShellState createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentTabIndex = 0; // 0: Scrapbook, 1: Studio, 2: Profile
  
  // Custom navigation state for nested/direct sub-screens
  // 'tabs', 'typewriter', 'evidence'
  String _currentDirectScreen = 'tabs';

  String _selectedTrip = "Cabo Fail '23";

  final Map<String, String> _tripLyrics = {
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

  late final Map<String, List<TimelineMemory>> _tripMemories = {
    "Cabo Fail '23": [
      const TimelineMemory(
        id: 'mem-1',
        time: '11:42 PM',
        author: '@alex',
        text: 'Alex tried to fight a seagull for the last churro. The seagull won. We are never returning to this pier.',
        icon: Icons.bolt,
        iconBg: BrutalTheme.yellow,
        category: 'FAIL',
        rotationDegrees: -2.0,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAqb6LbvBrW4Ue7MDpYvmzbpa3X5fcuFWPtqqrdKEiPjauXeqmVkyr1FoK2oQ86wIllp4eCLovXTDALySIyfTpuZsJKZIffX3GI4Wc4TVJgzAzWHsgNsxwMe0EDW12vTKwjH7Yo4x8epfn-t-uF4ABXKVfuhM5rJfJlCtfFIEhuWowtu075ufdeINuDczymoFN2gb7MNlwvSI5oSPkGiqsrI2KtTxhp16JhKwgBpo32ItQuvg_DLFOLCd8W8UsZtYnNhDrM9QUFG3k',
      ),
      const TimelineMemory(
        id: 'mem-2',
        time: '02:15 AM',
        author: '@sarah',
        text: 'Ended up at a 24hr laundromat playing poker with candy wrappers.',
        icon: Icons.local_fire_department,
        iconBg: BrutalTheme.primary,
        iconColor: Colors.white,
        rotationDegrees: 3.0,
      ),
      const TimelineMemory(
        id: 'mem-3',
        time: '04:00 AM',
        author: '@group',
        text: 'Karaoke meltdown. We owe the owner an apology for destroying \'Mr. Brightside\'.',
        icon: Icons.music_note,
        iconBg: BrutalTheme.yellow,
        rotationDegrees: -1.0,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAa9qiUmdAn3I64gl8K4ttDZttAwinQPlReLQZWN9kOMrbJVmCHh3RgR-xZU-4fr8CvUS5rD-ql8B8PB5XsPNnvYyZ0v00_KrlexLnLexSB_PqIX9f-lAE3tIeMZ5ijH95a1ALJfNJs-U9uEF6_kifH_8ISG6yah6Weuq6w1FO0TjnjW4VjGyIuTvrzvK6oVBs89ft5wtKJ4Cpx_SnJ4am_Tpb7T04QTErssDV2CC1yErbuA8DzUUFDrPuAefpcL8fRWO70WCXwDtM',
      ),
    ],
    "Mudfest 2024": [
      const TimelineMemory(
        id: 'mem-mud-1',
        time: '10:30 AM',
        author: '@dave',
        text: 'Truck got stuck in the first mud pit. Had to pay a tractor driver 50 bucks to pull us out.',
        icon: Icons.agriculture,
        iconBg: BrutalTheme.primary,
        iconColor: Colors.white,
        category: 'STUCK',
        rotationDegrees: 1.5,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCc1O6C08mrvt95HE72xNmasi9USWsLzudZ6cJ4daYEzP00r8WZyGTGOswVy5Rp9NOQYdCSUUiEPWxlXt12mS04t5KpWceFiA3tsou2zx8WgajfsEoQLFFQ7gBifUslUPasmMiRVyGfl4AckykcHEIjcWD4KXEF6OZbVdeP37vb2tbvRysbSyZLe3zy4sXMcMBYxgihyzGBswCogeH3aDyclR0AGtWq1E9C7KwCf1dzoC7oNbd0oTDywqP-c6-BQF-_TsvL56eBePg',
      ),
      const TimelineMemory(
        id: 'mem-mud-2',
        time: '02:00 PM',
        author: '@alex',
        text: 'Dropped the car keys in the mud. Spent 3 hours wading around with a metal detector.',
        icon: Icons.search,
        iconBg: BrutalTheme.yellow,
        rotationDegrees: -2.5,
      ),
    ],
    "Vegas Mistakes": [
      const TimelineMemory(
        id: 'mem-veg-1',
        time: '09:00 PM',
        author: '@alex',
        text: 'Put everything on red. It landed on black. Classic.',
        icon: Icons.casino,
        iconBg: BrutalTheme.primary,
        iconColor: Colors.white,
        category: 'RUINED',
        rotationDegrees: -2.0,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDzHiCujisdOlw0WKq1uRsTgRBI7Bla5tbL5tCLeiXv4PjEvhoa8Gphpzscsi-x9vRLdn_YoyrtRUxU2I5429zUug0ql1BlvuSbrhaN0vGIx5EIBu9lshCzSm0Z-jSJOCTc-uNprN6YUHjd2MxNa8URbJFsP8wE594vcUtCwk7LHvHYCTOtSNivNEnz14ecHC2RZ3PjgY_hG4t3TLKeOMA2PpbQcD13c3DrbAki8n2JW3w0mHyaeuampdYbAQbZRw3HPUnA-EmDoPw',
      ),
      const TimelineMemory(
        id: 'mem-veg-2',
        time: '01:30 AM',
        author: '@sarah',
        text: 'Lost our shoes at a pool party. Had to walk back to the hotel on scorching concrete.',
        icon: Icons.pool,
        iconBg: BrutalTheme.yellow,
        rotationDegrees: 1.5,
      ),
    ],
    "Roadtrip '22": [
      const TimelineMemory(
        id: 'mem-road-1',
        time: '01:00 PM',
        author: '@dave',
        text: 'Engine overheated in the middle of Death Valley. No cell service. Thankfully we had warm sodas.',
        icon: Icons.build,
        iconBg: BrutalTheme.yellow,
        category: 'HOT',
        rotationDegrees: -1.5,
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAg4EL78LnsYim1e5WkEBdzrj5BYFmyGTcTAttZCyyCXpya9F5BG1lA1jjLapZ-p4r4t8KI7lzb8SWGhVTDxEWbceYSeaYBqa0dyaan99fWy1NXXPC8rt_tw_-VpHz5syTQlJfIW5n4mAHV_rqear_-gVqwSgLlAnRD0A03gT-dJDTy8h2-duxFnTWcLIh6PrblLa7ehWdrR1HzQHTOkiKm3rSuzGL-2Mf7VCirqX-kATvRQl2CSeMdaokhtejeM-j9NmXmk70ES8g',
      ),
      const TimelineMemory(
        id: 'mem-road-2',
        time: '05:30 PM',
        author: '@alex',
        text: 'Stumbled upon a museum of giant concrete dinosaurs. Best 5 dollars ever spent.',
        icon: Icons.museum,
        iconBg: BrutalTheme.primary,
        iconColor: Colors.white,
        rotationDegrees: 2.0,
      ),
    ],
  };

  final Map<String, List<MapPin>> _tripMapPins = {
    "Cabo Fail '23": [
      const MapPin(memoryId: 'mem-1', label: 'THE INCIDENT', left: 50, top: 50),
      const MapPin(memoryId: 'mem-2', label: 'BAD IDEA #4', right: 80, bottom: 40),
    ],
    "Mudfest 2024": [
      const MapPin(memoryId: 'mem-mud-1', label: 'MUD PIT', left: 100, top: 70),
      const MapPin(memoryId: 'mem-mud-2', label: 'LOST KEYS', right: 60, bottom: 90),
    ],
    "Vegas Mistakes": [
      const MapPin(memoryId: 'mem-veg-1', label: 'ROULETTE', left: 40, top: 120),
      const MapPin(memoryId: 'mem-veg-2', label: 'HOT FEET', right: 120, top: 60),
    ],
    "Roadtrip '22": [
      const MapPin(memoryId: 'mem-road-1', label: 'OVERHEAT', left: 80, bottom: 100),
      const MapPin(memoryId: 'mem-road-2', label: 'DINO STOP', right: 90, top: 80),
    ],
  };

  final Map<String, String> _tripMapImages = {
    "Cabo Fail '23": 'https://lh3.googleusercontent.com/aida-public/AB6AXuDMHms3J94ZNjT47OBSVc9ASGToglMRsH4M7TugUYqZNLagdBdlXG1KkQElo-6WnvGjhEXccwWMfKlx0M3_H6tRGBmy79-ZmOSo27xJ5rrxDcID3eLSg5UuvwpTGwqDAsqWyIkgNckmm9DrKkjKi5V4Yt9S0G82nqo6IzhOScueF3PBzxCwRsaYhaj__lUaUtz_kCywpGJMPa_lIGe_qOHmc45eg0eUMTV3tJ2h_iMT8wc-vIZCMvk-V1-iymfJ0QjChcHhumJRg3w',
    "Mudfest 2024": 'https://lh3.googleusercontent.com/aida-public/AB6AXuCc1O6C08mrvt95HE72xNmasi9USWsLzudZ6cJ4daYEzP00r8WZyGTGOswVy5Rp9NOQYdCSUUiEPWxlXt12mS04t5KpWceFiA3tsou2zx8WgajfsEoQLFFQ7gBifUslUPasmMiRVyGfl4AckykcHEIjcWD4KXEF6OZbVdeP37vb2tbvRysbSyZLe3zy4sXMcMBYxgihyzGBswCogeH3aDyclR0AGtWq1E9C7KwCf1dzoC7oNbd0oTDywqP-c6-BQF-_TsvL56eBePg',
    "Vegas Mistakes": 'https://lh3.googleusercontent.com/aida-public/AB6AXuDzHiCujisdOlw0WKq1uRsTgRBI7Bla5tbL5tCLeiXv4PjEvhoa8Gphpzscsi-x9vRLdn_YoyrtRUxU2I5429zUug0ql1BlvuSbrhaN0vGIx5EIBu9lshCzSm0Z-jSJOCTc-uNprN6YUHjd2MxNa8URbJFsP8wE594vcUtCwk7LHvHYCTOtSNivNEnz14ecHC2RZ3PjgY_hG4t3TLKeOMA2PpbQcD13c3DrbAki8n2JW3w0mHyaeuampdYbAQbZRw3HPUnA-EmDoPw',
    "Roadtrip '22": 'https://lh3.googleusercontent.com/aida-public/AB6AXuAg4EL78LnsYim1e5WkEBdzrj5BYFmyGTcTAttZCyyCXpya9F5BG1lA1jjLapZ-p4r4t8KI7lzb8SWGhVTDxEWbceYSeaYBqa0dyaan99fWy1NXXPC8rt_tw_-VpHz5syTQlJfIW5n4mAHV_rqear_-gVqwSgLlAnRD0A03gT-dJDTy8h2-duxFnTWcLIh6PrblLa7ehWdrR1HzQHTOkiKm3rSuzGL-2Mf7VCirqX-kATvRQl2CSeMdaokhtejeM-j9NmXmk70ES8g',
  };

  void _navigateToDirectScreen(String screenName) {
    setState(() {
      _currentDirectScreen = screenName;
    });
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentDirectScreen = 'tabs';
      _currentTabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If we have an overlay screen (Typewriter or Evidence), render it directly
    if (_currentDirectScreen.toLowerCase() == 'typewriter') {
      return TypewriterScreen(
        onBack: () => _navigateToDirectScreen('tabs'),
        onProduceTrack: () => _navigateToTab(1), // Navigates to Studio tab
        tripName: _selectedTrip,
        initialLyrics: _tripLyrics[_selectedTrip] ?? "",
        memories: _tripMemories[_selectedTrip] ?? [],
        onLyricsUpdated: (newLyrics) {
          setState(() {
            _tripLyrics[_selectedTrip] = newLyrics;
          });
        },
      );
    } else if (_currentDirectScreen.toLowerCase() == 'evidence') {
      return EvidenceScreen(
        onBack: () => _navigateToDirectScreen('tabs'),
        tripName: _selectedTrip,
        mapImageUrl: _tripMapImages[_selectedTrip] ?? "",
        memories: _tripMemories[_selectedTrip] ?? [],
        mapPins: _tripMapPins[_selectedTrip] ?? [],
        onAddMemory: (newMemory) {
          setState(() {
            _tripMemories[_selectedTrip]?.add(newMemory);
          });
        },
      );
    }

    // Render Bottom Nav Shell
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          ScrapbookScreen(
            onNavigateToTab: _navigateToTab,
            onNavigateToDirectScreen: _navigateToDirectScreen,
            onTripSelected: (tripName) {
              setState(() {
                _selectedTrip = tripName;
              });
            },
            createdTrips: widget.tripStore?.trips ?? const [],
          ),
          BangerScreen(
            onBack: () => _navigateToTab(0), // Back to Scrapbook tab
            tripName: _selectedTrip,
            lyrics: _tripLyrics[_selectedTrip] ?? "",
          ),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: BrutalTheme.paper2, // secondary cream
          border: Border(
            top: BorderSide(color: Color(0xFFE7DBC0), width: 1.0),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 12.0, top: 8.0, left: 16.0, right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(
              index: 0,
              icon: Icons.book,
              label: 'Scrapbook',
            ),
            _buildBottomNavItem(
              index: 1,
              icon: Icons.play_circle,
              label: 'Studio',
            ),
            _buildBottomNavItem(
              index: 2,
              icon: Icons.person,
              label: 'Profile',
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
    final bool isActive = _currentTabIndex == index;
    final Color itemColor = isActive ? BrutalTheme.primary : BrutalTheme.graphite;
    
    return GestureDetector(
      onTap: () => _navigateToTab(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 30,
            color: itemColor,
          ),
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

// Simple Profile screen just to complete the bottom nav options
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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
          alignment: Alignment.center,
          child: SafeArea(
            child: Text(
              'MY PROFILE',
              style: GoogleFonts.instrumentSerif(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: BrutalTheme.inkBlack,
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: BrutalCard(
            color: BrutalTheme.card,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE1D4B6), width: 1.5),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuBq7EdCTPva73qwA0b7XoYyRoEyBXhGAw90E67gUzc0psJTDFanyVZs3kELGIGm_4vjezb5wLlMQMocryuJkkDRatqU5kQvwmCTg-whLJk3Q5Qh4BzcImyTZ4bxX-KAYh_xIBpNO8NYsdHnvkNDCoM5ECzF-GZk7AWbGz_pvX79MKljzYpXzfPiUi821FTgllT3Eq9eDcTpdC3px5WggNXfh5Hby8W8K1e9LLYMBRpPicZfj35Fb_Rsjzk4CUyamP1MJ30tuxdMt6Y',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '@ALEX_CHAOS',
                  style: GoogleFonts.instrumentSerif(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Trip Lead & Seagull Fighter',
                  style: GoogleFonts.karla(
                    fontSize: 14,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
