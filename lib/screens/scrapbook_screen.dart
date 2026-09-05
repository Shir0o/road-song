import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/trip_models.dart';
import '../theme.dart';
import '../widgets/brutal_widgets.dart';

const List<Color> _createdTripCoverColors = [
  Color(0xFFF1E7D1),
  Color(0xFFC05B3E),
  Color(0xFF3E6B8A),
  Color(0xFF7D8663),
  Color(0xFFB08A3E),
];

class ScrapbookScreen extends StatelessWidget {
  final Function(int) onNavigateToTab;
  final Function(String screenName) onNavigateToDirectScreen;
  final ValueChanged<String> onTripSelected;
  final List<Trip> createdTrips;

  const ScrapbookScreen({
    Key? key,
    required this.onNavigateToTab,
    required this.onNavigateToDirectScreen,
    required this.onTripSelected,
    this.createdTrips = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalTheme.backgroundLight,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66.0),
        child: Container(
          decoration: const BoxDecoration(
            color: BrutalTheme.paper2, // secondary cream
            border: Border(
              bottom: BorderSide(color: Color(0xFFE7DBC0), width: 1.0),
            ),
          ),
          alignment: Alignment.center,
          child: SafeArea(
            child: Text(
              'YOUR MESSY TRIPS',
              style: GoogleFonts.instrumentSerif(
                textStyle: const TextStyle(
                  color: BrutalTheme.inkBlack,
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      body: GrainOverlay(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 120.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column
                  Expanded(
                    child: Column(
                      children: [
                        _buildCaboCard(context),
                        const SizedBox(height: 24),
                        _buildVegasCard(context),
                        ..._buildCreatedTripCards(context, columnIndex: 0),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right Column
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 12), // offset for staggered effect
                        _buildMudfestCard(context),
                        const SizedBox(height: 24),
                        _buildRoadtripCard(context),
                        ..._buildCreatedTripCards(context, columnIndex: 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Floating Action Button matching the handoff + composition style
            Positioned(
              bottom: 100,
              right: 24,
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: BrutalTheme.primary,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.only(bottom: 180, left: 24, right: 24),
                      content: Text(
                        'CHAOS INITIALIZED! SELECT A TRIP TO START THE TEA.',
                        style: GoogleFonts.spaceMono(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BrutalTheme.brutalDecoration(
                    color: BrutalTheme.primary,
                    borderRadius: BorderRadius.circular(28),
                    shadowColor: const Color(0xB2C05B3E),
                    shadowOffset: const Offset(0, 8),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Trip Options Dialog Builder
  void _showTripOptions(BuildContext context, String tripName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: BrutalCard(
            color: BrutalTheme.card,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DymoLabel(text: tripName, fontSize: 16),
                const SizedBox(height: 16),
                Text(
                  'What do you want to edit or view for this trip?',
                  style: GoogleFonts.karla(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
                const SizedBox(height: 20),
                BrutalButton(
                  color: BrutalTheme.primary,
                  onPressed: () {
                    Navigator.pop(context);
                    onNavigateToDirectScreen('Typewriter');
                  },
                  child: Text(
                    'WRITE LYRICS (AI LYRICS)',
                    style: GoogleFonts.spaceMono(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                BrutalButton(
                  color: BrutalTheme.cyan,
                  onPressed: () {
                    Navigator.pop(context);
                    onNavigateToDirectScreen('Evidence');
                  },
                  child: Text(
                    'VIEW DIARY & MAP (THE EVIDENCE)',
                    style: GoogleFonts.spaceMono(
                      color: BrutalTheme.inkBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                BrutalButton(
                  color: BrutalTheme.yellow,
                  onPressed: () {
                    Navigator.pop(context);
                    onNavigateToTab(1); // Index 1 is Studio in main bottom nav
                  },
                  child: Text(
                    'PRODUCE TRACK (AI STUDIO)',
                    style: GoogleFonts.spaceMono(
                      color: BrutalTheme.inkBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '[ CLOSE ]',
                    style: GoogleFonts.spaceMono(
                      color: BrutalTheme.graphite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaboCard(BuildContext context) {
    return BrutalCard(
      color: BrutalTheme.yellow,
      rotationDegrees: -1.0,
      hasTape: true,
      tapeRotationDegrees: 3.0,
      onTap: () {
        onTripSelected("Cabo Fail '23");
        _showTripOptions(context, "Cabo Fail '23");
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                color: Colors.white,
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuB8fiqabi3I3z886FtHh2aaaVaMVgKkj0MgLXbHipZ2FHOuSCwRGDUwTyQ6pB3JqYsx8wBZOr_Msj_GvFK9Uhfft8sFF4Iwui6HiDz5OEuSL5qtpaAta6NjHP7T9T91QCxHanu6LwSP1EMIQkEDhjWAH1ndZtZD-k1EhguqhlXcWg2JqVKPrqnMNsIjfQoK0ZLZAuhlQEt6U3tUnQsISpQm11GuVTKmc1heY_3WDhX_141_Ox-JmoBjO55isYAy3zdr-Colz2fZwn8',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CABO FAIL '23",
                  style: GoogleFonts.instrumentSerif(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildAvatar('https://lh3.googleusercontent.com/aida-public/AB6AXuBq7EdCTPva73qwA0b7XoYyRoEyBXhGAw90E67gUzc0psJTDFanyVZs3kELGIGm_4vjezb5wLlMQMocryuJkkDRatqU5kQvwmCTg-whLJk3Q5Qh4BzcImyTZ4bxX-KAYh_xIBpNO8NYsdHnvkNDCoM5ECzF-GZk7AWbGz_pvX79MKljzYpXzfPiUi821FTgllT3Eq9eDcTpdC3px5WggNXfh5Hby8W8K1e9LLYMBRpPicZfj35Fb_Rsjzk4CUyamP1MJ30tuxdMt6Y'),
                    const SizedBox(width: 4),
                    _buildAvatar('https://lh3.googleusercontent.com/aida-public/AB6AXuD5LXLIM-C6xFwO5Yl67bYtVqeUHPZc5UppzkvbVVaNaR0UGgLOxlNokO863jd5j6bZ6jHbELY9810YFLNRk-t2SGo7FUlx3cR936i2BKI8RKT9GBTZoDxH4Xf0rtDXh7rfQXhvI1haL1zaH52GAmlWGMJRsv0zb241ItGftuwZjHdb5aP9TbR4EM5rN-dONwn5ti0RqZWAOJdcQ9I3jl3GouimdEvZxfzmCe-lqdy1kJpQ_i0Rs8ssvFQ__y_nDRcjYuWEaGxv5a0'),
                    const SizedBox(width: 4),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: BrutalTheme.cyan,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+2',
                        style: GoogleFonts.karla(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: BrutalTheme.inkBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMudfestCard(BuildContext context) {
    return BrutalCard(
      color: BrutalTheme.card,
      rotationDegrees: 2.0,
      onTap: () {
        onTripSelected("Mudfest 2024");
        _showTripOptions(context, "Mudfest 2024");
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                color: Colors.white,
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCc1O6C08mrvt95HE72xNmasi9USWsLzudZ6cJ4daYEzP00r8WZyGTGOswVy5Rp9NOQYdCSUUiEPWxlXt12mS04t5KpWceFiA3tsou2zx8WgajfsEoQLFFQ7gBifUslUPasmMiRVyGfl4AckykcHEIjcWD4KXEF6OZbVdeP37vb2tbvRysbSyZLe3zy4sXMcMBYxgihyzGBswCogeH3aDyclR0AGtWq1E9C7KwCf1dzoC7oNbd0oTDywqP-c6-BQF-_TsvL56eBePg',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "MUDFEST 2024",
                  style: GoogleFonts.instrumentSerif(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Transform.rotate(
                  angle: -2 * 3.14159 / 180,
                  child: Text(
                    "Never again...",
                    style: GoogleFonts.caveat(
                      color: BrutalTheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildAvatar('https://lh3.googleusercontent.com/aida-public/AB6AXuC8uhCZVdeFadbMnrz0wJV-brI8gekrKOtzAtT-jXMrbwzoTEcm5i85_8b8XT9wZMYt-6b4Cw_lAO9MPdqsQ3cwvkbjRQH4hzBuFB68H6lWLUNL8Wd7BpVim-3WNiFntmqrrPw2rHTRl4C4CxZ_-E4JUrrgTLN_adicfzDsi_KotyZl4-RFBfuvb7Jm24RuDctc7jz_a7G_AKGWS-HuhEzyHmvKz5R8zGiiI1iEx92CUuUILv6i6YboM04tCyJ3fjvFw3AIAB-HrGw'),
                    const SizedBox(width: 4),
                    _buildAvatar('https://lh3.googleusercontent.com/aida-public/AB6AXuCU2_zmIFRpkgWusvXog_OeYiNfSq2E7F-mTgBQDSodDP0vEgCerFiVh6gd3cvq-N84urrif-UUq1mkMZUV4_A1PndsP8huReQvOedq3TCgLon5EZVKcPkk3y4mD_dd4734W7SqFM49a0HMUswKI04y4hwi0Fpw1R9Z2IvPE3RDoXFXn46i2mSCZ9uZOpkjKdngtudurEmy_0_bCSKxm9TV0_dYL9-GAvAmeVZRMi7U3FFtlvxWGlNpEdCShSh4KmtOPL6vJ9tIEFU'),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVegasCard(BuildContext context) {
    return BrutalCard(
      color: BrutalTheme.primary,
      rotationDegrees: -2.0,
      onTap: () {
        onTripSelected("Vegas Mistakes");
        _showTripOptions(context, "Vegas Mistakes");
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.0),
                color: Colors.black,
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDzHiCujisdOlw0WKq1uRsTgRBI7Bla5tbL5tCLeiXv4PjEvhoa8Gphpzscsi-x9vRLdn_YoyrtRUxU2I5429zUug0ql1BlvuSbrhaN0vGIx5EIBu9lshCzSm0Z-jSJOCTc-uNprN6YUHjd2MxNa8URbJFsP8wE594vcUtCwk7LHvHYCTOtSNivNEnz14ecHC2RZ3PjgY_hG4t3TLKeOMA2PpbQcD13c3DrbAki8n2JW3w0mHyaeuampdYbAQbZRw3HPUnA-EmDoPw',
                  ),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black12, BlendMode.dstATop),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "VEGAS MISTAKES",
                  style: GoogleFonts.instrumentSerif(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: BrutalTheme.yellow,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildAvatar('https://lh3.googleusercontent.com/aida-public/AB6AXuD5_VCoHcnC1pLqMCyDVCqdL80braXgy_XDPAvqo1vPZzFWrf0oimhamj_541On7f3LvcP1fDoaDSH02AHKaWLu5ONF-u3Bwdi0lb6XmugL5xgACUWXEU3HMuc7qA6-Qunz-JKSrRJxboDK76UxKPRfulxHijcPJTlDlCJ6QeqhGccelZE1qZfQuNBRLVZZTelXauVNGsinMSa6Gb_mQ8SS8PkSGt9CUacivzeqY5qQLxJZIluwnzXunquaphS_iA5giN9cnQlVWv0'),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRoadtripCard(BuildContext context) {
    return BrutalCard(
      color: BrutalTheme.yellow,
      rotationDegrees: 1.0,
      onTap: () {
        onTripSelected("Roadtrip '22");
        _showTripOptions(context, "Roadtrip '22");
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
                color: Colors.white,
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuAg4EL78LnsYim1e5WkEBdzrj5BYFmyGTcTAttZCyyCXpya9F5BG1lA1jjLapZ-p4r4t8KI7lzb8SWGhVTDxEWbceYSeaYBqa0dyaan99fWy1NXXPC8rt_tw_-VpHz5syTQlJfIW5n4mAHV_rqear_-gVqwSgLlAnRD0A03gT-dJDTy8h2-duxFnTWcLIh6PrblLa7ehWdrR1HzQHTOkiKm3rSuzGL-2Mf7VCirqX-kATvRQl2CSeMdaokhtejeM-j9NmXmk70ES8g',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ROADTRIP '22",
                  style: GoogleFonts.instrumentSerif(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildAvatar('https://lh3.googleusercontent.com/aida-public/AB6AXuD5oayLuAuT-Jf8shcPbxOV0xGBf27cwpZVyFMJLCHGwGYNBp1-_V8Nyy_w1xGse8q0QauAG_uEL9uTT7FpyKWah6CQvZrBqEDrDyQqk8tkfVJb4XMN3I-7gkSGwy9_Cqz5t67P9ecpKVHnNPPpAR1AnIqfNv7e5hhi9Vm3hfKBNnewGKxbfksA-AricqPLxW8TqVOwiU8wUGV0BK1vU2ciA1TBZ2qtIg8r6EOj8S2wmNCxcDeVpbJGtMam3X2uHhL1QcXlDoTDtcs'),
                    const SizedBox(width: 4),
                    _buildAvatar('https://lh3.googleusercontent.com/aida-public/AB6AXuDCp5yQe-WSHgb-VV-LU-_Bi8lOk9kPjwRsXpPLgAuye71CoV0qktKJl6mMVEljAKwAaSDccpL6-IDxNw9RC1aBajcsMXbAKEBxHXKAsgsPEz6f5Dlwxixk6fmN6gngiUkqqafauyoqTI6fqvXvte4i9EugxgwpDjVJMSVigfpkEEkyO-mCtE71ne4QUL1VdvbZ7_QOO-6-IWmyw7n83QYcwfAoyZYTTTfkYITI-Lu293g66d7knlhprRXXVJc8Ncskk34mCS0YrvA'),
                    const SizedBox(width: 4),
                    _buildAvatar('https://lh3.googleusercontent.com/aida-public/AB6AXuCI53uuah8dIm4ygtMgHVSURuRqY8f496Lo_brU0Uq3_la6tX7AfZw1I7ThiSJvFtKZrfqLytWNDs9GlP1xGe5niDuccjaI32SkZ2-91LuchjJ__mdsdjonfRcOkB8bCFQk_bV0eYtgAGBsq1UU6F63Pof2WyUOWBKb-_pjRw1XotQX7YsRJl32w5xcf21H6qyAskjV7I6eJqQHWQlMiliI0b_8U9re_WpmvT02zimH0RwZcZ5GMdPoXZ_bauzTwzqPIF27uzXYSpY'),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildCreatedTripCards(
    BuildContext context, {
    required int columnIndex,
  }) {
    final List<Widget> cards = [];
    for (int i = 0; i < createdTrips.length; i++) {
      if (i % 2 == columnIndex) {
        cards.add(_buildCreatedTripCard(context, createdTrips[i]));
        cards.add(const SizedBox(height: 24));
      }
    }
    return cards;
  }

  Widget _buildCreatedTripCard(BuildContext context, Trip trip) {
    return BrutalCard(
      color: _createdTripCoverColors[trip.coverIndex % _createdTripCoverColors.length],
      rotationDegrees: -1.0,
      hasTape: true,
      tapeRotationDegrees: 3.0,
      onTap: () {
        onTripSelected(trip.name);
        _showTripOptions(context, trip.name);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.name.toUpperCase(),
                  style: GoogleFonts.instrumentSerif(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: BrutalTheme.inkBlack,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${trip.firstDay} – ${trip.lastDay}',
                  style: GoogleFonts.karla(
                    fontSize: 12,
                    color: BrutalTheme.graphite,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  trip.sessionLink,
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    color: BrutalTheme.graphite,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAvatar(String url) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE1D4B6), width: 1.0),
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
