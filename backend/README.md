# Road Song trip-store backend

The hosted trip store behind the guest loop: Cloudflare **Workers + D1 + R2 +
static assets** (per `research/backend-options.md` and Implementation Decision 6
of issue #21). The guest website is the **same Flutter web build** in an
anonymous guest mode (Decision 7, option A — one codebase, one deploy), served
as static assets by this Worker.

- **No accounts.** Every request carries the trip code; the Worker resolves
  `code -> trip_id` and only ever reads/writes rows for that trip. Cross-trip
  access is impossible by construction: there is no endpoint that takes a
  memory id without its trip code, and every query filters on `trip_id`.
- **Media scope.** R2 object keys are scoped under `trips/<tripId>/…`; the
  Worker only ever mints URLs for keys it generated for that trip, and the
  memory row is only created after the object exists in R2.
- **Uploads.** The Worker returns a short-lived (15 min) R2 **presigned PUT
  URL** with `Content-Type` pinned in the signature — a mismatched MIME fails
  `403 SignatureDoesNotMatch` at R2. The browser/app PUTs bytes directly to R2
  (zero egress, no Worker request in the data path).
- **Serving.** Media is served via short-lived (1 h) presigned GET URLs minted
  per request. R2 has zero egress fees at every tier.

## Contract

Base URL: `https://<worker>/api`. All bodies are JSON. Errors are
`{ "error": "…" }` with a 4xx/5xx status.

### `POST /api/trips`

Creates a trip (creator app). Body: `{ "name": "…", "firstDay": "…", "lastDay": "…", "coverIndex": 0 }`.

Returns `201` with the trip (including its generated `code` — the
`roadsong.app/t/<code>` link) and an empty `memories` list.

### `GET /api/trip/:code`

Returns the trip and its memories (oldest first). Media memories carry a fresh
presigned GET `mediaUrl`.

```json
{
  "id": "…", "code": "…", "name": "…", "firstDay": "…", "lastDay": "…",
  "coverIndex": 0, "createdAt": "2026-09-10T…",
  "memories": [
    {
      "id": "…", "type": "photo|video|text",
      "contributor": "Maya", "author": "@maya",
      "caption": "…", "text": "…", "day": 1, "dayDate": "JUN 12",
      "locationName": "…", "latitude": null, "longitude": null,
      "mediaUrl": "https://…presigned…", "createdAt": "2026-09-10T…"
    }
  ]
}
```

`404` when the code is unknown.

### `POST /api/trip/:code/upload-url`

Body: `{ "type": "photo|video", "contentType": "image/jpeg", "contentLength": 12345 }`

Returns `{ "uploadUrl": "…presigned PUT…", "mediaKey": "trips/<tripId>/<uuid>.<ext>" }`.

- `413` when `contentLength` exceeds the guardrail: **12 MB photos, 64 MB
  videos** (mirrors the app's `kMaxPhotoUploadBytes` / `kMaxVideoUploadBytes`).
- The presigned URL expires after 15 minutes and only accepts the exact
  `Content-Type` sent in this request.

### `POST /api/trip/:code/memories`

Body (text memory):

```json
{
  "type": "text",
  "contributor": "Maya", "author": "@maya",
  "caption": "…", "text": "…", "day": 1, "dayDate": "JUN 12",
  "locationName": "…", "latitude": null, "longitude": null
}
```

Body (photo/video memory — after the bytes were PUT to `uploadUrl`):

```json
{
  "type": "photo", "mediaKey": "trips/<tripId>/<uuid>.jpg",
  "contributor": "Maya", "author": "@maya", "caption": "…", "text": "…"
}
```

Returns the created memory (`201`). `mediaKey` must start with
`trips/<thisTripId>/` and the object must already exist in R2 — both are
enforced server-side.

### `GET /api/trip/:code/media/:memoryId`

Returns `{ "url": "…presigned GET…" }` for one memory's media. `404` when the
memory doesn't exist **on that trip** (cross-trip lookup is impossible).

### `DELETE /api/trip/:code/memories/:memoryId`

Deletes the memory row and its R2 object. `404` when the memory doesn't exist
on that trip.

## Trip-code scope model

- The trip code is the only credential. It is the secret that gates the trip:
  anyone with the link can read and contribute (that is the product — no
  accounts, share by link).
- The Worker never accepts a memory id without its trip code, and every D1
  query filters on `trip_id` resolved from the code. There is no endpoint that
  enumerates trips or memories across trips.
- Media keys embed the trip id; `handleCreateMemory` rejects keys that don't
  start with `trips/<thisTripId>/`, and `handleGetMedia`/`handleDeleteMemory`
  look up `WHERE id = ? AND trip_id = ?`.
- R2 objects are only ever reachable through presigned URLs minted by the
  Worker for a verified trip; the bucket is private.

## Deploy

Prereqs: a Cloudflare account, `npx wrangler` (or a local wrangler install),
and the Flutter web build output.

1. **Build the web app** (the guest + creator surface):

   ```sh
   cd .. && flutter build web --release
   ```

2. **Copy the build into the Worker's static assets**:

   ```sh
   rm -rf public && cp -R ../build/web public
   ```

3. **Create the D1 database and apply the schema**:

   ```sh
   npx wrangler d1 create road-song
   # copy the printed database_id into wrangler.toml
   npx wrangler d1 migrations apply road-song --remote
   ```

   (Or, without migrations: `npx wrangler d1 execute road-song --remote --file=./schema.sql`.)

4. **Create the R2 bucket**:

   ```sh
   npx wrangler r2 bucket create road-song-media
   ```

5. **R2 S3 API credentials** (for presigning). Create an API token with
   "Object Read & Write" scoped to the bucket in the Cloudflare dashboard
   (R2 → Manage R2 API Tokens), then:

   ```sh
   npx wrangler secret put R2_ACCESS_KEY_ID
   npx wrangler secret put R2_SECRET_ACCESS_KEY
   npx wrangler secret put R2_ACCOUNT_ID
   ```

6. **Deploy**:

   ```sh
   npx wrangler deploy
   ```

7. **Point the app at the backend.** The Flutter client reads the base URL
   from `--dart-define=ROAD_SONG_API_BASE` (see
   `lib/services/remote_trip_store.dart`); the default is the local fake used
   by tests. For a real deploy, build with:

   ```sh
   flutter build web --release --dart-define=ROAD_SONG_API_BASE=https://road-song.<your-subdomain>.workers.dev
   ```

   The trip link shape is `roadsong.app/t/<tripCode>`; the Worker's
   single-page-application fallback serves the Flutter build for those paths,
   and the app's guest route reads the code from the URL.

## Local development

The Worker can run locally with `npx wrangler dev` (D1/R2 need `--local`
bindings or a logged-in account). The Flutter side never needs the real
backend in CI: the store-client contract suite runs against a fake backend
(`test/fake_backend.dart`) and the whole-app flow tests inject it at the app
seam — no real network in CI.
