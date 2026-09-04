# Trip-store & guest-upload backend options (issue #13)

**Status:** Research complete — Sept 4, 2026. All limits/prices verified against primary sources (official pricing pages and docs, checked this week); see the "Sources" list at the end of each section and the consolidated URL list. Scale assumptions: **v1 = one trip, 5–20 real guests, ~200 photos (≈1.5–5 MB each) + a few short videos (≈50–150 MB each) → roughly 0.5–2 GB stored, read-mostly diary/memorial playback** (a full watch-through ≈ 0.5–1 GB egress). "Growth" = **10–100 trips**.

## Recommendation (TL;DR)

**Use Cloudflare (Workers + D1 + R2; guest site as static assets on the same Worker).** It is the only one of the three that is genuinely $0 at v1 *without* a payment method, a forced plan upgrade, or a pause-on-inactivity clause; R2 has **zero egress fees**, which is the dominant cost driver for a photo/video playback app; and the business plan's presigned-URL / scoped-code upload pattern is the native, documented R2 pattern (S3 SigV4 presigned PUT/GET, 1 s–7 day expiry). Firebase's Cloud Storage is **no longer usable on the no-cost Spark plan at all (enforced since 2026-02-03)**, so "Firebase on the free tier" is no longer a real option for a media app; Supabase's free tier caps media at **50 MB per file**, shares one **10 GB/month total egress** bucket across DB+storage, and **pauses the whole project after 1 week of inactivity** — disqualifying for a memorial that must play back months later. Supabase Pro ($25/mo) and Firebase Blaze (pay-as-you-go) are fine products, but both cost money and/or impose billing risk at v1 where Cloudflare stays free; Cloudflare's main cost is DIY creator auth (fine for a single-creator v1).

**Bottom line for the decision ticket:** *Cloudflare Workers + D1 + R2 + static assets; scope guests by trip code checked in a Worker, upload/download via short-lived R2 presigned URLs; ≈$0/month through v1 and well past 100 trips; only real follow-up is creator auth as the product grows.*

| Criterion (v1, one trip ≈ 0.5–2 GB, few-GB/mo playback) | Cloudflare (Workers+D1+R2) | Firebase (Firestore+Storage+Hosting) | Supabase (Postgres+Storage) |
|---|---|---|---|
| Hard $0 at v1, no card on file | **Yes** — Workers Free 100k req/day, D1 free, KV free, R2 free tier (10 GB-mo, egress $0) | No — Cloud Storage requires **Blaze** since 2026-02-03 (card on file, no hard spend cap) | Free plan exists but pauses after 7 days idle + 50 MB/file cap + 10 GB/mo shared egress |
| Media egress cost | **$0 forever** (R2 has no egress charges at any tier) | No-cost 100 GB/mo downloads (new `firebasestorage.app` buckets), then ≈GCS egress (~$0.12/GiB) | 5 GB free egress + 5 GB cached; Pro: 250+250 GB included |
| Guest web uploads (anonymous, no accounts) | Presigned PUT from Worker — documented, first-class; POST not supported (use PUT/fetch) | Anonymous Auth + rules, or Cloud Function minting GCS signed URLs; needs Functions (Blaze) for real trip scoping | Anonymous sign-ins + RLS, or `createSignedUploadUrl` (TUS `x-signature`); needs one Edge Function/RPC for code check |
| Guest web site hosting | Free static assets on same Worker/Pages | Firebase Hosting free (10 GB, 360 MB/day transfer) | **Not included** — host elsewhere (Netlify/Vercel/Pages) |
| Flutter upload path | Plain HTTPS PUT to presigned URL (trivial in Dart); no SDK needed | `firebase_storage` SDK upload, first-class on iOS/Android/web | `supabase_flutter` `.upload()` fine; **no native TUS resumable** wrapper (community pkg) |
| Trip-scoped "code" auth | Worker checks code vs D1, returns single-object presigned URL — minimal DIY | Anonymous auth + custom claims (Admin SDK/CF) or signed URLs from CF | Anonymous auth + RLS row in `trip_guests`, or SECURITY DEFINER RPC |
| Playback latency | R2 via Cloudflare edge; custom-domain caching optional; zero-egress makes range/video cheap | GCS + Google CDN front; tokenized download URLs | Supabase CDN (Basic free, Smart on Pro); signed URLs JWTs |
| Ops burden | Code (Wrangler) + tiny dashboard; no billing at v1; D1 free limits hard-enforced since 2026-09-01 (design queries/indexes) | Console-heavy; Blaze billing + budget alerts; rules + Functions deploys | Nice dashboard/SQL; migrations; free-tier pause monitoring |
| 10–100 trips | Still ≈$0–5/mo (storage overage only: $0.015/GB-mo; egress $0); no plan change, no pausing | Cost grows with reads past 50k/day + storage past 5 GB + egress past 100 GB/mo; monitor (no hard cap) | Free pauses/dies at 10 GB egress → **Pro $25/mo** (+compute incl.) or self-manage egress; storage incl. 100 GB |
| Watch-outs | DIY creator auth (no consumer-auth product); D1 row-read accounting (indexes) | Blaze required day 1; no hard spend cap (budget alerts a must) | 50 MB/file free cap; 7-day pause; 10 GB/mo egress cap; web uploads best via TUS |

---

## 1. Cloudflare — Workers + D1 (+KV) + R2 (+ static assets/Pages)

### 1.1 Free tier, verified (pricing pages updated Aug–Sep 2026)

| Resource | Free limit | Source |
|---|---|---|
| Workers requests | 100,000/day (dynamic invocations); **requests to static assets are free and unlimited** | [workers/platform/pricing](https://developers.cloudflare.com/workers/platform/pricing/) |
| Workers CPU | 10 ms/invocation (free); 5-min max on Paid | same |
| Workers KV | 100k reads/day, 1k writes/day, 1k deletes/day, 1k lists/day, 1 GB stored; limits reset 00:00 UTC, excess operations fail | same |
| D1 (SQLite) | 5M rows read/day, 100k rows written/day, 5 GB stored; **hard-enforced since Sept 1, 2026** (errors until UTC reset) | [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/), [2026-09-01 changelog](https://developers.cloudflare.com/changelog/post/2026-09-01-d1-free-tier-limit-enforcement/) |
| R2 | 10 GB-month storage, 1M Class A ops/mo, 10M Class B ops/mo, **egress free (all tiers, all storage classes)** | [R2 pricing](https://developers.cloudflare.com/r2/pricing/) |
| Workers Logs | 200k log events/day, 3-day retention (free) | [workers pricing](https://developers.cloudflare.com/workers/platform/pricing/) |
| Paid (only when needed) | $5/mo min (Standard usage): 10M requests + 30M CPU-ms incl; D1 5 GB incl then $0.75/GB-mo; R2 $0.015/GB-mo over 10 GB, Class A $4.50/M, Class B $0.36/M | same pages |

Key facts for this product:

- **D1 free limits are now strictly enforced (2026-09-01 changelog)** — exceeding 5M row-reads or 100k row-writes/day returns errors until midnight UTC; Cloudflare explicitly advises indexes to avoid full-table scans because reads are counted per row scanned. v1 traffic is ~3–4 orders of magnitude below the caps; just index `media(trip_id)` etc.
- KV free caps (1k writes/day) are fine for v1 (write-per-upload records live in D1 instead).
- **R2 zero egress at every tier** ([pricing](https://developers.cloudflare.com/r2/pricing/) — "There are no charges for egress bandwidth for any storage class", including r2.dev/custom-domain/Workers/S3-API reads) is the single most important line for a media app. Served-playback bandwidth never appears on a bill.
- **Static assets on Workers**: static-file requests are free/unlimited; no charge for storing assets; only Worker-script invocations bill. [static-assets billing](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/). Pages is still supported but Cloudflare now points new full-stack projects at Workers with static assets; either can host the guest site for $0 (Pages Functions bill as Workers). (Pages product pricing page has been folded into Workers docs; pages static hosting remains free via the Workers platform.)
- Guest-site + API + DB + media in one account/one deploy; no cross-vendor egress.

### 1.2 Trip-code scoping + upload/download path (matches business plan §2.1)

R2 **presigned URLs are a documented, supported pattern** (S3 SigV4), expiry 1 s–7 days, for GET/HEAD/PUT/DELETE on a *single object*; **POST form uploads are not supported** (browser uploads use `fetch`/XHR PUT), and presigned URLs cannot be attached to custom domains (S3 API endpoint only). [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)

Flow (all through one Worker, D1 for state):

1. Guest opens `https://guest.<yoursite>/t/<trip-code>` (static assets, free). SPA calls `POST /api/upload-url` with the code + file name/type.
2. Worker looks up `trips` in D1 by code (store only a salted hash if you want code confidentiality), checks trip is active/accepting, rate-limits per code (KV counter), generates a **fresh object key** (`trips/<tripId>/<uuid>.<ext>`) and returns a **presigned PUT URL, 10–15 min expiry, `ContentType` pinned in the signature** so a different MIME fails `403 SignatureDoesNotMatch`; also inserts a pending `media` row (D1).
3. Browser (and the Flutter app) PUTs the bytes **directly to R2** — no Worker request, no egress cost, one Class A op (1M/mo free). Guest never sees R2 credentials; exposure is one expiring, single-object, type-pinned URL.
4. Creator app (Flutter, iOS/Android/web) calls `GET /api/trip/:id/media` with a creator credential → Worker returns metadata + **presigned GET URLs (short expiry, e.g. 15–60 min) minted per request**, or flips approved items public on a custom domain for memorial playback.

Media serving notes: reads via presigned URLs hit the S3 API endpoint directly (no cache but zero egress and Cloudflare's network); for heavily-replayed memorial content, connect a custom domain to the bucket and enable Cloudflare Cache (Smart Tiered Cache) — R2 public-bucket docs confirm custom-domain caching; `r2.dev` is dev-only/rate-limited and must be off for private trips. WAF HMAC token auth can protect a custom-domain bucket but needs a Pro zone — presigned GETs avoid that for v1. [public buckets](https://developers.cloudflare.com/r2/buckets/public-buckets/)

Ops burden: everything is code in the repo (Wrangler `wrangler deploy`), a small dashboard for metrics/logs (3-day retention free). No billing dashboard anxiety at v1; the account needs no payment method on the free plan.

### 1.3 Growth to 10–100 trips

- Storage: 100 trips × ~0.5–1 GB ≈ 50–100 GB → R2 free tier ends at 10 GB-mo; overage **$0.015/GB-mo ≈ $0.60–1.35/mo**. Egress stays $0. Class B reads: full watch-through ≈ 10M objects/mo *only* past ~333k watch-throughs/mo of 200-photo trips — i.e., never a factor here. Realistic total: **$0–6/mo** (Workers paid only if >100k dynamic requests/day, which even 100 trips of this scale won't approach if media is served from R2 URLs rather than proxied).
- Effort: none — same architecture, no per-trip or per-project migration. Watch D1 row-read accounting as data grows (indexes; avoid full scans). KV stays trivial.
- The main scaling gap is not infra but **creator identity**: Workers has no consumer-auth product; for many trips you'd add real creator accounts (email magic-link via your own token/email flow, or a third-party auth such as Auth0/Clerk in front of the same Worker+R2 API) — plan the API around a creator credential from day one. Ops also stay DIY (no managed "project pause/backup" buttons; D1 Time Travel gives 7-day PITR on free).

---

## 2. Firebase — Firestore + Cloud Storage + Hosting

### 2.1 The 2026 pricing reality: Cloud Storage requires Blaze, period

- Firebase has two plans: **Spark (no-cost)** and **Blaze (pay-as-you-go)**. On the current pricing page (updated 2026-09-02) every Cloud Storage row shows **"Not applicable" under Spark** — including the free daily allowances — while Blaze keeps "no-cost up to…" quotas. [firebase.google.com/pricing](https://firebase.google.com/pricing)
- Official FAQ: *"Cloud Storage for Firebase (even default buckets) now requires projects to be on the pay-as-you-go Blaze pricing plan… This requirement went into effect starting **February 03, 2026**."* On Spark, storage API calls fail `402/403`, console access is blocked. No-cost usage still exists *on Blaze*. [FAQ](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)
- Consequence: **a Firebase media app (photos/videos) cannot run on the no-cost plan at all** — Spark still gives Firestore (1 GiB, 50k reads/day, 20k writes/day, 20k deletes/day, 10 GiB egress/mo) and Hosting (10 GB storage, 360 MB/day transfer) and Auth (50k MAU) for free, but the actual media bytes require Blaze from day 1: card on file, **no hard spending cap** (budget alerts are the standard mitigation), overage billed at GCS rates.
- Blaze no-cost allowances for the *new-style* default bucket (`*.firebasestorage.app`, all new projects since Sept 2024): **5 GB-months stored, 100 GB/month downloaded, 5k upload ops/mo, 50k download ops/mo**, then Google Cloud Storage pricing (regional ~$0.02/GB-mo storage; egress ≈$0.12/GiB). Legacy `*.appspot.com` buckets keep their older allowances (5 GB, 1 GB/day downloaded, 20k uploads/day, 50k downloads/day, then App Engine pricing $0.026/GB-mo / $0.12/GB). [pricing](https://firebase.google.com/pricing) + [FAQ](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)
- Firestore per-unit rates beyond the daily free quota (Iowa/us-central1, current pricing page): reads $0.03/100k, writes $0.09/100k, deletes $0.01/100k, storage ≈$0.15/GiB-mo. [cloud.google.com/firestore/pricing](https://cloud.google.com/firestore/pricing)
- Cloud Functions (needed below for scoped uploads) are Blaze-only (Spark: "Not applicable"): 2M invocations/mo no-cost on Blaze. [pricing](https://firebase.google.com/pricing)

### 2.2 Trip-code scoping + upload/download path

Firebase's model is client SDKs + server-enforced **Security Rules**, not presigned URLs; Firebase Storage rules cannot cross-read Firestore, so true trip scoping needs a trusted signer. Two viable designs:

- **Design A (SDK + anonymous auth + custom claims).** Guest web page calls `signInAnonymously()` (free; JS and Flutter both supported) [anonymous auth](https://firebase.google.com/docs/auth/web/anonymous-auth), then a **Cloud Function (callable, Blaze)** verifies the trip code (against Firestore) and sets a scoped custom claim on the anonymous uid (`tripAccess: {tripId: exp}`) — custom claims can only be set by Admin SDK, hence the Function. Firestore rules: creator (`uid == trips/{id}.creator`) reads all; guests read nothing. Storage rules: `allow create/update: if request.auth.token.tripAccess[pathTrip]` scoping writes to `trips/<tripId>/…`; creator-only reads for playback. Upload from web or Flutter = `firebase_storage` `uploadBytes`/`putFile` (first-class on iOS/Android/web, resumable put with progress). No presigned URLs needed.
- **Design B (closest to the business plan: Cloud-Function-minted signed URLs).** Callable Function validates code, then returns a **short-lived GCS signed upload URL** (`@google-cloud/storage` `generateSignedUrl` PUT, admin creds); guest/creator PUTs bytes directly to GCS (works from any HTTP client incl. Flutter `http`). Playback: Function returns short-lived signed GET URLs (15–60 min) per item instead of long-lived `getDownloadURL` tokens. This keeps media paths off rules entirely and gives true expiring access — at the cost of one Function call per URL mint.

Media serving: downloads go through Google's CDN-fronted GCS; `getDownloadURL` token URLs are convenient and revocable but effectively long-lived bearer links, so prefer Design B's short signed GETs (or token URLs only for explicitly-shared memorial links). Playback latency is good globally; range requests for video work.

Ops burden: console-centric (auth providers, rules, usage/billing pages), rules + Functions deployed from the repo (`firebase deploy`), Blaze billing with no hard cap → budget alerts + monitoring recommended; Functions add a deployable code unit. Hosting the guest site is included and free-tier (10 GB / 360 MB/day) but page traffic counts against Hosting's transfer allowance.

### 2.3 Growth to 10–100 trips

- 100 trips ≈ 50–100 GB media: storage crosses 5 GB no-cost → ~$1–2/mo at GCS rates. Firestore: playback lists are read-heavy — past ~50k doc-reads/day (≈250 full 200-photo album opens/day) reads bill at $0.03/100k (≈$0.90 per 3M reads) — negligible until real scale. **Egress is the only real variable**: 100 GB/mo downloads are no-cost; a busy memorial month past that ≈$0.12/GiB. Expect **~$2–15/mo at 100 trips with zero infrastructure work** — but no hard cap means a viral memorial or a runaway sync loop can bill; set budgets/alerts.
- Effort: no architecture change — same Firestore/Storage/Functions code per trip; Firestore scales horizontally for free. Multiple buckets per project (Blaze) allow per-tier lifecycle rules later.

---

## 3. Supabase — Postgres + Storage (+Auth +Edge Functions)

### 3.1 Free tier, verified (supabase.com/pricing, current)

| Resource | Free | Pro ($25/mo org incl. one Micro compute; $10/mo per extra project) |
|---|---|---|
| Database | 500 MB (shared CPU/RAM); **no automatic backups; project pauses after 1 week of inactivity** (2 active projects max) | 8 GB disk incl., then $0.125/GB; daily backups 7 days; never pauses |
| Storage | 1 GB files; **max file size 50 MB** | 100 GB incl., then $0.0213/GB; max file 500 GB |
| Egress | **5 GB + 5 GB cached**, shared across DB+storage+functions (10 GB total/mo) | 250 GB + 250 GB cached incl., then $0.09/$0.03 per GB |
| Auth | 50k MAU; anonymous sign-ins incl. | 100k MAU incl. |
| Edge Functions | 500k invocations/mo | 2M/mo incl. |
| CDN / other | Basic CDN; no custom domains (Pro add-on $10/domain/mo) | Smart CDN; custom domains add-on |
| Support/limits | Community; logs 1 day | Email; logs 7 days |

Sources: [supabase.com/pricing](https://supabase.com/pricing); egress is "sum of all data transferred from database, storage, and functions" — [bandwidth/egress doc](https://supabase.com/docs/guides/storage/serving/bandwidth).

The three free-tier facts that matter most for this product: **(a) 50 MB per-file cap** (a 1-minute 1080p phone clip commonly exceeds it → guest clips must be capped/compressed, or pay for Pro); **(b) 10 GB/month total egress** (a handful of full memorial watch-throughs plus the trip's own uploads can approach this; it's one shared bucket across all services); **(c) 1-week inactivity pause** — a memorial viewed on anniversaries, not daily, will be paused and require a manual dashboard wake, so the free plan is effectively unusable as the production home of a durable memorial.

### 3.2 Trip-code scoping + upload/download path

Supabase has the best out-of-the-box scoping primitives (real Postgres + RLS + Auth), used as follows:

1. **Guests (web + Flutter):** `signInAnonymously()` (supported in JS and Dart SDKs; JWT carries `is_anonymous`; anonymous users run as the `authenticated` role) [anonymous sign-ins](https://supabase.com/docs/guides/auth/auth-anonymous). On code entry, the app calls a small **Edge Function** (or `SECURITY DEFINER` RPC) that checks the trip code and inserts `trip_guests(anon_uid, trip_id)`; storage policies then key off that row — e.g. `storage.objects` insert policy: `bucket_id='trip-uploads' and exists (select 1 from trip_guests where trip_id = (storage.foldername(name))[1] and anon_uid = auth.uid())`. RLS on the `media` table restricts reads to the trip creator.
2. **Uploads:** for photos and any file ≤6 MB use the SDK `.upload()` (authenticated). For larger video from the guest web page, Supabase's documented large-file path is **TUS resumable uploads** with a signed-upload token: `createSignedUploadUrl(path)` returns a token sent as the `x-signature` header; upload URLs live up to 24 h. [resumable uploads doc](https://supabase.com/docs/guides/storage/uploads/resumable-uploads). **Flutter gap:** `supabase_flutter` has no native TUS client — `uploadToSignedUrl`/`.upload()` exist, but resumable large-video upload from the creator Flutter app needs a community package or hand-rolled chunking (short clips or Pro-tier bandwidth make this tolerable at v1). The "pure presigned, no SDK" variant also exists (same signed-upload token over plain HTTP).
3. **Download/playback:** `createSignedUrl(path, expiresInSeconds)` returns a per-object JWT URL (expiry chosen by caller; treat as short-lived; unique token per call, so cache URLs client-side or mint on demand). [storage signed URLs](https://supabase.com/docs/guides/storage/serving/signed-urls) (guide page now lives under the storage docs tree; JS API `createSignedUrl`). Alternatively flip a bucket/folder public for explicit memorial sharing, or proxy through the CDN. Creator playback in Flutter = select approved `media` rows (RLS) then mint signed GETs.

Ops burden: excellent dashboard + SQL (Studio), migrations in-repo, no server code for most of the auth/scoping story (RLS + a couple of SQL policies/RPCs). You must host the guest **website** elsewhere (Supabase does not host static sites — Netlify/Vercel/Cloudflare Pages all fine, one extra hop) and watch: free-project pause status, egress meter (10 GB/mo free), and the 50 MB file cap.

### 3.3 Growth to 10–100 trips

- Staying on free at 100 trips is not viable: egress (10 GB/mo shared) breaks first, then storage (1 GB) and DB (500 MB); and free still pauses. **Pro at $25/mo** (org plan incl. Micro compute) removes pausing, raises storage to 100 GB incl., egress to 500 GB incl. (250+250), backups 7 days, max file 500 GB — a 100-trip, ~50–100 GB media estate fits inside Pro's included allowances with zero variable cost, and overages are cheap ($0.0213/GB storage, $0.09/GB egress). Total ≈ **$25–35/mo at 100 trips** (extra compute if traffic warrants).
- Effort: schema/RLS scales as-is (each trip = rows + a bucket folder); no sharding needed at this scale. Budget: fixed plan, spend caps on by default — better cost predictability than Firebase Blaze.

---

## 4. What changed in 2025–2026 that flips the comparison

- **Firebase Cloud Storage off Spark for everyone (2026-02-03)** — the biggest change. "Free Firebase" media apps now require Blaze + card + no-hard-cap billing. [FAQ](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024), [pricing](https://firebase.google.com/pricing)
- **Cloudflare D1 free-tier limits hard-enforced (2026-09-01)** — row-read/write caps now return errors, not throttling; fine at this scale, but queries must be indexed/cheap. [changelog](https://developers.cloudflare.com/changelog/post/2026-09-01-d1-free-tier-limit-enforcement/)
- **Cloudflare product positioning** — Pages remains supported but Cloudflare recommends Workers + static assets for new apps; Pages Functions bill as Workers. The business plan's "Pages/R2" instinct is satisfied by one Worker serving static assets + R2 (or Pages, still fine). [static-assets billing](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/)
- **R2 presigned URLs are a first-class documented pattern** (1 s–7 day expiry; single-object; no POST) — exactly the business plan's §2.1 mechanism, no S3-in-front needed. [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)
- **Supabase free tier** tightened around egress/scale and kept the 7-day pause + 50 MB/file limits; anonymous sign-ins are now standard for guest flows. [pricing](https://supabase.com/pricing), [anonymous auth](https://supabase.com/docs/guides/auth/auth-anonymous)

## 5. Sources (all fetched Sept 2026; current as of the date on each page)

- Cloudflare Workers pricing & limits — https://developers.cloudflare.com/workers/platform/pricing/
- Cloudflare R2 pricing (free tier, zero egress) — https://developers.cloudflare.com/r2/pricing/
- Cloudflare R2 presigned URLs — https://developers.cloudflare.com/r2/api/s3/presigned-urls/
- Cloudflare R2 public buckets / custom-domain caching — https://developers.cloudflare.com/r2/buckets/public-buckets/
- Cloudflare Workers static assets billing — https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/
- Cloudflare D1 pricing — https://developers.cloudflare.com/d1/platform/pricing/ ; D1 free-limit enforcement changelog (2026-09-01) — https://developers.cloudflare.com/changelog/post/2026-09-01-d1-free-tier-limit-enforcement/
- Firebase pricing (Spark vs Blaze; Cloud Storage "Not applicable" on Spark) — https://firebase.google.com/pricing
- Firebase Cloud Storage billing FAQ (Blaze required; effective 2026-02-03) — https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- Firebase anonymous auth — https://firebase.google.com/docs/auth/web/anonymous-auth
- Cloud Firestore pricing (unit rates; free daily quota) — https://cloud.google.com/firestore/pricing
- Supabase pricing (Free/Pro limits incl. 50 MB file cap, egress, pausing) — https://supabase.com/pricing
- Supabase storage egress/bandwidth — https://supabase.com/docs/guides/storage/serving/bandwidth
- Supabase resumable (TUS) uploads + signed upload tokens — https://supabase.com/docs/guides/storage/uploads/resumable-uploads
- Supabase anonymous sign-ins — https://supabase.com/docs/guides/auth/auth-anonymous
