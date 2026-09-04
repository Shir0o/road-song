# Route-map rendering options for Road Song v1 (Flutter)

- **Ticket:** [Research: Flutter route-map rendering options](https://github.com/Shir0o/road-song/issues/14) · part of [v1 wayfinder map](https://github.com/Shir0o/road-song/issues/12), feeds [zip-flow IA prototype](https://github.com/Shir0o/road-song/issues/17)
- **Research date:** 2026-09-04 · all URLs verified this date; package versions/activity pulled live from pub.dev and GitHub APIs
- **Scope reminder:** creator app targets **iOS + Android + web**; v1 is one trip, dependency-light, offline-tolerant, neo-brutalist; the Route screen shows ~5–10 pinned memories ("5 stops · 320 km of coast … map placeholder") and the repo today has **no location capture, no map code, no models** (verified: no `LatLng`/geo fields in `lib/`; memories are text `TimelineMemory` fixtures).

---

## Recommendation (TL;DR)

**Ship v1 with a stylized self-drawn route (Option B): a `CustomPaint` route line + pins over the app's own flat brutalist background. Store a nullable `lat`/`lng` pair on each pinned place from day one so real tiles are a drop-in upgrade, not a migration.**

Real interactive tiles (flutter_map, maplibre_gl, google_maps_flutter) are all viable and healthy in 2026, but none of them fits v1's constraints for the Route screen:

1. **Cost/license/attribution burden is real and ongoing.** Every credible hosted tile source either forbids what v1 needs or costs money/logo space: OSMF raster+vector tile servers are community-funded, best-effort, **prohibit offline/prefetch**, and require a real User-Agent + attribution ([OSM raster policy](#source-osm-raster), [OSM vector policy](#source-osm-vector)); MapTiler's free tier is **non-commercial, requires their logo, and pauses when the 100k/mo request quota is hit**; Google requires a billing-enabled project with API keys and its Terms prohibit offline/caching use. A custom drawing uses **no third-party basemap at all** — no tile policy, no keys, no attribution, no quota, no cost.
2. **The design is a stylized poster map, not a satellite/street view.** The neo-brutalist aesthetic (flat paper palette, hard offset shadows, thick borders — `BrutalTheme` in `lib/theme.dart`) fights photographic cartography; an illustration-layer route matches it exactly. Real tiles would need heavy re-styling (flat/vector styling) to not look pasted-on, and a vector-styled basemap is the one option with the highest integration effort (MapLibre style authoring).
3. **Offline-tolerance is free with custom drawing and awkward or prohibited with tiles** (details per option below).
4. **v1 has no coordinates for anything.** With name-only pinned places, a tile map cannot place pins at all without adding a geocoding service (Nominatim is free but rate-limited and policy-bound; MapTiler/Google geocoding cost money/keys). A stylized route can render from an ordered list of labeled stops with **zero geo data**, and can still look geographically plausible when demo fixtures carry optional coords.

**Post-v1 trigger to revisit:** the moment the product needs street-level geographic context (real roads/coast under the route), user pan/zoom on real geography, or a "where were we" moment in the diary — adopt **flutter_map** first (healthiest package, cheapest credible sources, pure-Flutter web parity). If a heavily customized flat vector style over real geography is required, that is the point to evaluate MapLibre styling (maplibre_gl or flutter_map_maplibre plugin). google_maps_flutter is the weakest fit on every axis that matters here (web gaps, no offline, keys+billing, closed styling).

---

## Constraints that drive the decision

| Constraint (source) | Consequence |
|---|---|
| Ships Flutter web (issue #12 settled scope: iOS + Android + web) | Web support quality of the map stack is a first-class requirement, not a footnote |
| v1 dependency-light, offline-tolerant (issue #14) | Fewer native/platform-view plugins and no hard network dependency preferred |
| Neo-brutalist design; Route screen is a stylized "map placeholder" (issue #14) | The look is an illustration; photographic tiles may be a worse fit than a drawn map |
| No location capture exists yet; memories are text-only (repo verification) | Coordinate acquisition (GPS/pick/geocode) is a *new* product problem, not a map-rendering one |
| One trip, prototype (issue #12) | Ops overhead (API keys, quotas, billing, tile-source policy compliance) is pure tax on v1 |

---

## Option A — Real interactive tiles

### A.1 Package health & web support (2026-09-04, live data)

| | **flutter_map** | **maplibre_gl** | **google_maps_flutter** |
|---|---|---|---|
| Latest / published | 8.3.2 / 2026-08-27 (8.4.0-dev in flight) | 0.27.0 / 2026-08-19 | 2.18.0 / 2026-07-23 |
| License | BSD-3 | BSD-3 | BSD-3 |
| Publisher / repo | fleaflet.dev · github.com/fleaflet/flutter_map | maplibre.org · github.com/maplibre/flutter-maplibre-gl | flutter.dev · flutter/packages monorepo |
| GitHub activity | pushed 2026-09-04, ~3.0k★, 46 open issues, not archived | pushed 2026-09-04, 363★, 85 open issues, not archived | steady commits 2026-09-04 (monorepo, first-party) |
| pub.dev score | 160 | 160 | 150 |
| Web support | ✅ pure-Flutter renderer (CanvasKit/skwasm), `wasm-ready`; no platform view | ✅ via MapLibre GL JS in a platform view; WebGL2, Safari 15+; "web needs no index.html changes" | ✅ via Maps JavaScript API + `<script>` key tag, `HtmlElementView` platform view |
| Mobile | Android/iOS (+desktop) | Android/iOS only (no desktop) | Android (SDK 24+), iOS (14+) |
| Renderer note | Dart-only; pixel-identical behavior across web/mobile | "Map is a platform view … your widgets go over it in a Stack" | Platform views; overlays need `pointer_interceptor` on web |
| Known web gaps | none structural | no offline regions on web; WebGL2 requirement | no my-location button/My Location layer, no lite mode, no `defaultMarkerWithHue` (bring your own pin assets), compass/tilt options ignored, indoor/building layers missing ([README](https://pub.dev/packages/google_maps_flutter_web)) |

**Reading:** all three are maintained. flutter_map is the most active community project and has the cleanest web story because there is no native engine — it renders maps in Flutter itself, so web behavior and quality match mobile. maplibre_gl is healthy (maplibre.org publisher, BSD-3, monthly releases) but small (363★) and wraps two *different* native engines (maplibre-native on Android/iOS, maplibre-gl-js on web) behind one API — expect platform nuance; it explicitly does not support desktop or Flutter widgets inside the map. google_maps_flutter is first-party Google but the web implementation is the least complete of the three and inherits Google Maps Platform's key/billing/policy baggage.

### A.2 Tile sources — policy, cost, attribution (2026)

flutter_map/maplibre_gl render tiles but are **not** tile sources. The policy/cost reality of the sources a v1 app could use:

#### OpenStreetMap Foundation tiles (free, community-funded — not a production SLA)

- **Raster** (`tile.openstreetmap.org`) and **vector** (`vector.openstreetmap.org`, Shortbread schema) both exist and are free, but OSMF is explicit: *"OpenStreetMap data is free … **Our tile servers are not**"*; availability is best-effort with **no SLA**, and access **may be blocked without notice**. Requirements include a valid identifying **User-Agent** (library defaults get blocked), **visible attribution** ("© OpenStreetMap contributors"), honoring cache headers, and **no bulk download / no offline prefetch** — *"Offline use is not permitted on tile.openstreetmap.org"* (raster policy) and bulk downloading is likewise prohibited on the vector service. ([raster policy](https://operations.osmfoundation.org/policies/tiles/), [vector policy](https://operations.osmfoundation.org/policies/vector/))
- flutter_map itself now steers apps away: v8.2.0 "added warning on usage of OpenStreetMap public tile servers with `TileLayer`" and v8.3.0 "removed OSM unblocking flow" (its old workaround for OSM blocks) ([CHANGELOG](https://github.com/fleaflet/flutter_map/blob/master/CHANGELOG.md)).
- **Verdict:** fine for a dev build / tiny prototype, unsuitable as the dependency of a shipped app.

#### MapLibre demo tiles — dev/test only, not a real basemap

- The well-known `https://demotiles.maplibre.org/style.json` (used in maplibre_gl's own quickstart) is a **sample** — country polygons from Natural Earth, zoom 0–6, ~4 MB world file — explicitly "used in the helloworld examples and CI tests," not street-level cartography ([demo tiles repo](https://github.com/maplibre/demotiles)). It cannot render a 320 km coastal drive meaningfully. MapLibre is vendor-neutral: production apps bring their own tiles (OSM vector, MapTiler, self-hosted, …).

#### MapTiler — free tier is non-commercial + logo; $30/mo for commercial

- Pricing page (2026-09-04): **Free** = "Suitable for testing, personal or non-commercial use," **"MapTiler logo on the map"**, 100k **API requests**/mo (vector tile = 1 request; raster 256 = 1, 512 = 4) — and *"On a FREE plan service will pause until the next month"* when the quota is hit. **Flex = $30/mo** → 500k requests, commercial use, no logo; overage $0.15/1k requests ([pricing](https://www.maptiler.com/cloud/pricing/)).
- Note the billing model: unlimited "sessions" apply to MapTiler's own SDKs; **third-party SDKs like flutter_map are billed per tile API request**, so pan/zoom burns requests.
- Attribution is mandatory and specific: *"Our maps must always visibly show attribution: © MapTiler © OpenStreetMap contributors"* ([MapTiler copyright](https://www.maptiler.com/copyright/)).
- MapTiler does offer a genuine offline story via its paid/enterprise tiers — not on the free plan.

#### Google Maps Platform — keys + billing + no offline; native SDK row now "Unlimited", web still metered

- Requires a Google Cloud project with billing enabled, per-platform API keys (Maps SDK for Android/iOS; **Maps JavaScript API** for web — the web implementation needs a `<script>` tag with the key in `web/index.html` per [google_maps_flutter_web README](https://pub.dev/packages/google_maps_flutter_web)).
- Pricing (2026-09-01 price list): per-SKU free caps replaced the old $200 monthly credit on 2025-03-01 ([Google's announcement](https://developers.google.com/maps/billing-and-pricing/march-2025)). In the current list, the **Maps SDK (native Android/iOS) Essentials SKU shows "Unlimited"** free usage, while **Dynamic Maps (the Maps JavaScript API SKU — i.e., the web path) is 10,000 free loads/mo then $7.00/1,000** (tiered down with volume); Map Tiles API is 100k free tile requests/mo then $0.60/1k ([pricing list](https://developers.google.com/maps/billing-and-pricing/pricing)).
- **Offline is prohibited.** Google Maps Platform ToS bars pre-fetching, indexing, storing, or caching map content; the Map Tiles API policy is explicit that *"Offline uses"* are not permitted ([ToS](https://cloud.google.com/maps-platform/terms), [Map Tiles API policies](https://developers.google.com/maps/documentation/tile/policies)). There is no offline mode for third-party apps — the consumer Google Maps app's offline maps feature is not available through the APIs.
- Attribution: Google logo/attribution must remain visible and unaltered (per the policies pages above).

#### Bundled offline tile files (MBTiles/PMTiles) — the only real-tile offline route

- flutter_map has ecosystem providers for packaged archives: `flutter_map_mbtiles` and `flutter_map_pmtiles` (both under the active [josxha/flutter_map_plugins](https://github.com/josxha/flutter_map_plugins) repo; plugin versions 2026-04); maplibre_gl natively supports **PMTiles sources on Android/iOS/Web** and offline-region downloads on Android/iOS only ([README](https://github.com/maplibre/flutter-maplibre-gl)).
- **Licensing caveat:** packaging OSM-derived tiles means redistributing OSM data. OSM data is ODbL: attribution is required, and share-alike obligations apply to derived *databases* (small regional extracts are generally treated as fine with attribution — OSMF's own wording: *"small extractions are likely to be covered by fair usage / fair dealing"*, [Nominatim policy](https://operations.osmfoundation.org/policies/nominatim/), which echoes the OSM licence position). Prebuilt regional archives (e.g. Protomaps PMTiles planet/regional extracts, protomaps.com) exist but bring their own commercial terms — verify before bundling.
- This is real offline-capable real-tile territory, but it is an authoring/licensing pipeline, not a v1 default.

### A.3 Option A summary against v1 constraints

- **flutter_map + hosted tiles:** lightest real-tiles path; pure-Dart web parity is excellent; but still needs a compliant tile source (OSM = policy risk + no offline; MapTiler free = non-commercial + logo + quota; Google = keys + billing + no offline). Cache plugin exists but live-tile caching only gives you "recently viewed" resilience, not true offline.
- **maplibre_gl:** best when you need deep vector styling or packaged offline (PMTiles) later; heaviest integration (style authoring, platform-view constraints, two engine backends), web has no offline regions.
- **google_maps_flutter:** first-party, but web is the weakest implementation of the three, styling is closed, offline is contractually impossible, and it imposes keys + billing on every platform. **Reject for this app.**

---

## Option B — Stylized self-drawn route (CustomPaint)

**What it is:** a `CustomPaint` (or simple `Stack` of positioned widgets) that projects the trip's ordered pin list onto a flat canvas — polyline connecting stops, pin markers, labels — over the app's brutalist background, with the same hard offset shadows / thick `inkBlack` borders the rest of the UI uses (`lib/theme.dart` palette: paper cream `#F8F2E4`, brick `#C05B3E`, ink `#443729`, etc. — the aesthetic language already exists to draw with).

**Effort estimate (engineering judgment, grounded in repo):**
- Static poster route (design-accurate): one `RouteMapPainter` + a layout pass (fit bounds → padding, or sequence layout), pin hit-testing for tap-to-memory ≈ **0.5–1 dev-day**, no new dependencies, zero platform setup.
- With light interactivity (pan/zoom via `InteractiveViewer`, tap pins): **+0.5 day**.
- Geographically true line (actual lat/lngs projected with a simple equirectangular fit, if fixtures have coords): **+0.5 day** — still tiny.
- Compare: any real-tile option costs at least the same in integration plus ongoing source policy/keys/attribution work.

**Visual ceiling vs the brutalist design:** high — this is the *only* option that can match the design's static illustrated map 1:1, because the design *is* an illustration. Photographic tiles sit outside the aesthetic (a real "320 km of coast" basemap would fight the flat paper look unless heavily re-styled). The ceiling is geographic fidelity, not aesthetics: without a basemap there are no real roads/coastlines under the line. For a memorial-trip poster that is a feature, not a bug; if real geography is ever required, that is the flutter_map trigger (A.3).

**Does custom drawing avoid tile policy entirely?** Yes. No third-party imagery is fetched or displayed: no OSM/MapTiler/Google terms, no attribution, no User-Agent rules, no quotas, no keys, no billing. The route geometry is the user's own data (memory coordinates or even just ordered stops), which has no policy at all. (If you later *bundle* geographic reference data — e.g., a coastline polyline asset — the source data's license reapplies; v1 doesn't need it.)

**Offline behavior:** fully offline by construction; identical rendering on web, iOS, and Android because it is pure Flutter drawing. This is the only option where "offline-tolerant" is unconditional rather than "prohibited" (Google), "policy-limited" (OSM), or "native-only" (maplibre regions).

---

## Option C — data model: what a "pinned place" must store

This is the part that decides whether Option B is a dead end. It isn't — **if the schema is additive.**

| Renderer | Minimum per pin | Works with name-only? |
|---|---|---|
| Real tiles (any) | **decimal lat/lng (WGS84)**; name optional for the label | ❌ No — a pin with no coordinate cannot be placed. You'd have to geocode the name at capture time via a geocoding API (free Nominatim: max 1 req/s, valid User-Agent, attribution, no autocomplete, results must be cached, apps must be able to switch away on request — [Nominatim policy](https://operations.osmfoundation.org/policies/nominatim/); MapTiler/Google geocoding costs keys/money) |
| Stylized route | ordered list + **label text**; lat/lng *optional* to draw a geographically true line | ✅ Yes — sequence layout renders fine with zero geo |
| Stylized route, geo-true | lat/lng (nullable, same field) | falls back to sequence layout |

**Minimum v1 schema (recommended):** on each memory that is a "pinned place" (the Add-Memory "place" type), store:

```dart
class MemoryPlace {
  final String name;   // human label — always required, shown on every route render
  final double? lat;   // WGS84 decimal degrees — nullable in v1
  final double? lng;   // nullable in v1
  final int sequence;  // order along the trip route (or derive from memory timestamp)
}
```

Rationale:
- `name` is the only field v1's UX can honestly populate today (no location capture exists; nothing in `lib/` records coordinates — verified).
- Making `lat`/`lng` **nullable-but-present from day one** means demo fixtures can carry coordinates (the design's "5 stops · 320 km of coast" can be real-looking), the stylized painter can do a geo-true projection when coords exist and a clean sequence layout otherwise, and the flutter_map upgrade later is additive — no data migration.
- Do **not** model a free-text place as the sole data and silently geocode it later: name→coordinate resolution is a service decision (Nominatim vs paid), not a rendering concern, and geocoded names are ambiguous ("Cabo" ≠ a point).

**Implications for the Add Memory screen (feeds issue #17):**
- The v1 "pinned place" input should be a **name text field (+ optional coordinate capture deferred)** — not a map picker, not a geocode-on-save pipeline. A map picker/GPS capture is a real feature that needs permissions, keys, and offline policy, and v1 has no coordinates to justify it.
- Keep the memory type explicit (`place` vs photo/text/lore) so the Route screen knows which memories to pin.
- If tiles are adopted post-v1, Add Memory gains a "pin on map" step at *that* point; the schema above absorbs it without a rewrite.

---

## Decision & rationale

**Adopt Option B (stylized self-drawn route) for v1; store nullable coordinates; revisit with flutter_map when real geography is required.**

Evidence recap:
1. **Maintenance:** no v1 dependency needed at all. When needed later, flutter_map is the healthiest pure-Dart choice (8.3.2, 2026-08-27; active repo; web+wasm first-class); maplibre_gl is viable but heavier; google_maps_flutter is the weakest fit for this app.
2. **Cost/license:** hosted tile sources are either best-effort/non-production (OSMF), non-commercial+logo+quota (MapTiler free, $30/mo to go commercial), or keys+billing+no-offline (Google). Custom drawing has zero cost, zero attribution, zero keys.
3. **Aesthetic:** the design is an illustrated map; the app already owns the drawing language (theme, brutal widgets). Real tiles would be the odd surface out.
4. **Offline:** stylized route is unconditionally offline; every tile path is prohibited, limited, or native-only.
5. **Data reality:** v1 memories have no coordinates; a stylized route renders from ordered labeled stops, while tiles would force a geocoding service into v1.

**Risks / limits of the recommendation (honest):** the stylized map conveys memory sequence and vibe, not navigable geography; if users expect to *see where the trip went* against real roads/coast, that expectation belongs to a later iteration (flutter_map + MapTiler Flex or self-hosted tiles, or MapLibre + PMTiles for true offline). The repo contains no Route screen yet, so Option B's effort assumes one new widget + tests; the ≥90% coverage rule applies as usual.

---

## Sources (all accessed 2026-09-04)

- <a name="source-osm-raster"></a>OSMF Tile Usage Policy (raster) — https://operations.osmfoundation.org/policies/tiles/
- <a name="source-osm-vector"></a>OSMF Vector Tile Usage Policy — https://operations.osmfoundation.org/policies/vector/
- OSMF Nominatim Usage Policy — https://operations.osmfoundation.org/policies/nominatim/
- flutter_map on pub.dev — https://pub.dev/packages/flutter_map · CHANGELOG — https://github.com/fleaflet/flutter_map/blob/master/CHANGELOG.md · repo — https://github.com/fleaflet/flutter_map
- maplibre_gl on pub.dev — https://pub.dev/packages/maplibre_gl · README — https://github.com/maplibre/flutter-maplibre-gl
- MapLibre demo tiles — https://github.com/maplibre/demotiles
- google_maps_flutter / google_maps_flutter_web on pub.dev — https://pub.dev/packages/google_maps_flutter · https://pub.dev/packages/google_maps_flutter_web · source — https://github.com/flutter/packages/tree/main/packages/google_maps_flutter
- MapTiler Cloud pricing — https://www.maptiler.com/cloud/pricing/ · MapTiler copyright/attribution — https://www.maptiler.com/copyright/
- Google Maps Platform pricing list (updated 2026-09-01) — https://developers.google.com/maps/billing-and-pricing/pricing · 2025 pricing-model change — https://developers.google.com/maps/billing-and-pricing/march-2025 · Terms of Service — https://cloud.google.com/maps-platform/terms · Map Tiles API policies — https://developers.google.com/maps/documentation/tile/policies
- flutter_map plugins (cache/mbtiles/pmtiles) — https://github.com/josxha/flutter_map_plugins
- Repo context: issues #12/#14/#17 (github.com/Shir0o/road-song), `lib/theme.dart`, `lib/main.dart` (TimelineMemory fixtures), `pubspec.yaml`
