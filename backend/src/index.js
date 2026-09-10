/**
 * Road Song trip-store Worker.
 *
 * Thin, boring backend: Cloudflare Workers + D1 + R2 + static assets.
 * No accounts. Every request carries the trip code in the path; the Worker
 * resolves code -> trip_id and only ever reads/writes rows for that trip, so
 * trip-code scope is enforced server-side. Media is uploaded straight to R2
 * via short-lived presigned PUT URLs (type-pinned in the signature) and
 * served via short-lived presigned GET URLs minted per request.
 *
 * Endpoints (all under /api):
 *   GET    /api/trip/:code                 -> trip + memories (media GET URLs minted)
 *   POST   /api/trip/:code/upload-url      -> { uploadUrl, mediaKey } for a photo/video
 *   POST   /api/trip/:code/memories        -> create a memory (text, or media after upload)
 *   GET    /api/trip/:code/media/:memoryId -> { url } presigned GET for one memory's media
 *   DELETE /api/trip/:code/memories/:id    -> remove a memory (creator/contributor)
 *   PUT    /api/trip/:code/song            -> publish the finished memorial (audio ref + lyrics + line-level timeline)
 *   GET    /api/trip/:code/song            -> the published memorial, or 404 when not published
 *
 * Size guardrails (server-side, mirroring the app's 12 MB / 64 MB limits):
 * upload-url rejects contentLength above the per-type cap with 413, and the
 * presigned PUT signature pins Content-Type so a mismatched MIME fails at R2.
 */

import { createHmac, createHash } from 'node:crypto';

const MAX_PHOTO_BYTES = 12 * 1024 * 1024; // 12 MB
const MAX_VIDEO_BYTES = 64 * 1024 * 1024; // 64 MB
const UPLOAD_URL_TTL_SECONDS = 15 * 60; // 15 min
const MEDIA_URL_TTL_SECONDS = 60 * 60; // 1 h

function json(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

function badRequest(message) {
  return json({ error: message }, 400);
}

function notFound(message = 'Not found') {
  return json({ error: message }, 404);
}

function methodNotAllowed() {
  return json({ error: 'Method not allowed' }, 405);
}

/** Resolves a trip code to its row, or null. */
async function tripByCode(env, code) {
  const { results } = await env.DB.prepare(
    'SELECT * FROM trips WHERE code = ?',
  ).bind(code).all();
  return results[0] || null;
}

/** Memories of a trip, oldest first. */
async function memoriesForTrip(env, tripId) {
  const { results } = await env.DB.prepare(
    'SELECT * FROM memories WHERE trip_id = ? ORDER BY created_at ASC',
  ).bind(tripId).all();
  return results;
}

function memoryToJson(memory, mediaUrl) {
  return {
    id: memory.id,
    type: memory.type,
    contributor: memory.contributor,
    author: memory.author,
    caption: memory.caption,
    text: memory.text,
    day: memory.day,
    dayDate: memory.day_date,
    locationName: memory.location_name,
    latitude: memory.latitude,
    longitude: memory.longitude,
    mediaUrl,
    createdAt: memory.created_at,
  };
}

/** Parses the stored memorial JSON, or null when the trip has no song. */
function songFromRow(trip) {
  if (!trip.song) return null;
  try {
    return JSON.parse(trip.song);
  } catch (_) {
    return null;
  }
}

/* ------------------------------------------------------------------ *
 * S3 SigV4 presigning (R2's documented pattern for short-lived URLs). *
 * ------------------------------------------------------------------ */

function iso8601(date) {
  return date.toISOString().replace(/[:-]|\.\d{3}/g, '');
}

function hex(bytes) {
  return Buffer.from(bytes).toString('hex');
}

function hmac(key, data) {
  return createHmac('sha256', key).update(data).digest();
}

function sha256Hex(data) {
  return createHash('sha256').update(data).digest('hex');
}

function uriEncode(value) {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase(),
  );
}

function signingKey(secret, dateStamp) {
  const kDate = hmac(`AWS4${secret}`, dateStamp);
  const kRegion = hmac(kDate, 'auto');
  const kService = hmac(kRegion, 's3');
  return hmac(kService, 'aws4_request');
}

/**
 * Builds a presigned URL for one R2 object.
 *
 * For PUT, [contentType] is included in the signed headers, so the signature
 * only validates when the client sends that exact Content-Type — a mismatched
 * MIME fails with 403 SignatureDoesNotMatch at R2.
 */
function presignUrl(env, { method, key, contentType, ttlSeconds }) {
  const now = new Date();
  const amzDate = iso8601(now);
  const dateStamp = amzDate.slice(0, 8);
  const host = `${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`;
  const bucket = env.R2_BUCKET_NAME || 'road-song-media';
  const objectPath = `/${bucket}/${key}`;

  const credential = `${env.R2_ACCESS_KEY_ID}/${dateStamp}/auto/s3/aws4_request`;

  const queryParams = {
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': credential,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': String(ttlSeconds),
    'X-Amz-SignedHeaders': contentType ? 'content-type;host' : 'host',
  };
  const canonicalQuery = Object.keys(queryParams)
    .sort()
    .map((k) => `${uriEncode(k)}=${uriEncode(queryParams[k])}`)
    .join('&');

  const canonicalHeaders =
    (contentType ? `content-type:${contentType}\n` : '') + `host:${host}\n`;
  const signedHeaders = contentType ? 'content-type;host' : 'host';

  const canonicalRequest = [
    method,
    objectPath,
    canonicalQuery,
    canonicalHeaders,
    signedHeaders,
    'UNSIGNED-PAYLOAD',
  ].join('\n');

  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    `${dateStamp}/auto/s3/aws4_request`,
    sha256Hex(canonicalRequest),
  ].join('\n');

  const signature = hex(
    hmac(signingKey(env.R2_SECRET_ACCESS_KEY, dateStamp), stringToSign),
  );

  return `https://${host}${objectPath}?${canonicalQuery}&X-Amz-Signature=${signature}`;
}

/* ------------------------------------------------------------------ *
 * Handlers.                                                          *
 * ------------------------------------------------------------------ */

async function handleCreateTrip(env, body) {
  const name = String(body.name || '').trim().slice(0, 120);
  if (name.length === 0) return badRequest('name is required');

  const firstDay = String(body.firstDay || '').slice(0, 20);
  const lastDay = String(body.lastDay || '').slice(0, 20);
  const coverIndex = Number.isInteger(body.coverIndex) ? body.coverIndex : 0;

  // Code: slugified name + short random suffix for uniqueness. Retry a few
  // times on the (unlikely) collision.
  const slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40) || 'trip';

  let code = null;
  for (let attempt = 0; attempt < 5; attempt++) {
    const candidate = `${slug}-${crypto.randomUUID().slice(0, 4)}`;
    const existing = await tripByCode(env, candidate);
    if (!existing) {
      code = candidate;
      break;
    }
  }
  if (!code) return json({ error: 'Could not allocate a trip code' }, 500);

  const id = crypto.randomUUID();
  const createdAt = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO trips (id, code, name, first_day, last_day, cover_index, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).bind(id, code, name, firstDay, lastDay, coverIndex, createdAt).run();

  return json(
    {
      id,
      code,
      name,
      firstDay,
      lastDay,
      coverIndex,
      createdAt,
      memories: [],
      song: null,
    },
    201,
  );
}

async function handleGetTrip(env, code) {
  const trip = await tripByCode(env, code);
  if (!trip) return notFound('Trip not found');
  const memories = await memoriesForTrip(env, trip.id);
  return json({
    id: trip.id,
    code: trip.code,
    name: trip.name,
    firstDay: trip.first_day,
    lastDay: trip.last_day,
    coverIndex: trip.cover_index,
    createdAt: trip.created_at,
    song: songFromRow(trip),
    memories: memories.map((m) =>
      memoryToJson(
        m,
        m.media_key
          ? presignUrl(env, {
              method: 'GET',
              key: m.media_key,
              ttlSeconds: MEDIA_URL_TTL_SECONDS,
            })
          : null,
      ),
    ),
  });
}

async function handleUploadUrl(env, code, body) {
  const trip = await tripByCode(env, code);
  if (!trip) return notFound('Trip not found');

  const type = body.type;
  const contentType = body.contentType;
  const contentLength = Number(body.contentLength);

  if (type !== 'photo' && type !== 'video') {
    return badRequest('type must be "photo" or "video"');
  }
  if (typeof contentType !== 'string' || contentType.length === 0) {
    return badRequest('contentType is required');
  }
  if (!Number.isFinite(contentLength) || contentLength <= 0) {
    return badRequest('contentLength is required');
  }

  const limit = type === 'photo' ? MAX_PHOTO_BYTES : MAX_VIDEO_BYTES;
  if (contentLength > limit) {
    return json(
      {
        error:
          type === 'photo'
            ? 'That file is too big — keep photos under 12.0 MB.'
            : 'That file is too big — keep clips under 64.0 MB.',
      },
      413,
    );
  }

  const extension = contentType.split('/').pop()?.split(';')[0] || 'bin';
  const mediaKey = `trips/${trip.id}/${crypto.randomUUID()}.${extension}`;
  return json({
    uploadUrl: presignUrl(env, {
      method: 'PUT',
      key: mediaKey,
      contentType,
      ttlSeconds: UPLOAD_URL_TTL_SECONDS,
    }),
    mediaKey,
  });
}

async function handleCreateMemory(env, code, body) {
  const trip = await tripByCode(env, code);
  if (!trip) return notFound('Trip not found');

  const type = body.type;
  if (type !== 'photo' && type !== 'video' && type !== 'text') {
    return badRequest('type must be "photo", "video" or "text"');
  }

  let mediaKey = null;
  if (type !== 'text') {
    mediaKey = body.mediaKey;
    if (
      typeof mediaKey !== 'string' ||
      !mediaKey.startsWith(`trips/${trip.id}/`)
    ) {
      return badRequest('mediaKey is required and must belong to this trip');
    }
    // The object must actually exist in R2 before the memory row is created.
    const head = await env.R2.head(mediaKey);
    if (head === null) {
      return badRequest('Media object not found — upload it first');
    }
  }

  const id = crypto.randomUUID();
  const createdAt = new Date().toISOString();
  const contributor = String(body.contributor || 'Guest').slice(0, 80);
  const author = String(body.author || '@guest').slice(0, 80);
  const caption = String(body.caption || '').slice(0, 500);
  const text = String(body.text || '').slice(0, 5000);
  const day = Number.isInteger(body.day) ? body.day : 1;
  const dayDate = body.dayDate ? String(body.dayDate).slice(0, 20) : null;
  const locationName = body.locationName
    ? String(body.locationName).slice(0, 200)
    : null;
  const latitude = Number.isFinite(body.latitude) ? body.latitude : null;
  const longitude = Number.isFinite(body.longitude) ? body.longitude : null;

  await env.DB.prepare(
    `INSERT INTO memories
       (id, trip_id, type, contributor, author, caption, text, day, day_date,
        location_name, latitude, longitude, media_key, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).bind(
    id,
    trip.id,
    type,
    contributor,
    author,
    caption,
    text,
    day,
    dayDate,
    locationName,
    latitude,
    longitude,
    mediaKey,
    createdAt,
  ).run();

  return json(
    memoryToJson(
      {
        id,
        type,
        contributor,
        author,
        caption,
        text,
        day,
        day_date: dayDate,
        location_name: locationName,
        latitude,
        longitude,
        media_key: mediaKey,
        created_at: createdAt,
      },
      mediaKey
        ? presignUrl(env, {
            method: 'GET',
            key: mediaKey,
            ttlSeconds: MEDIA_URL_TTL_SECONDS,
          })
        : null,
    ),
    201,
  );
}

async function handleGetMedia(env, code, memoryId) {
  const trip = await tripByCode(env, code);
  if (!trip) return notFound('Trip not found');

  const { results } = await env.DB.prepare(
    'SELECT * FROM memories WHERE id = ? AND trip_id = ?',
  ).bind(memoryId, trip.id).all();
  const memory = results[0];
  if (!memory || !memory.media_key) return notFound('Media not found');

  return json({
    url: presignUrl(env, {
      method: 'GET',
      key: memory.media_key,
      ttlSeconds: MEDIA_URL_TTL_SECONDS,
    }),
  });
}

async function handleDeleteMemory(env, code, memoryId) {
  const trip = await tripByCode(env, code);
  if (!trip) return notFound('Trip not found');

  const { results } = await env.DB.prepare(
    'SELECT * FROM memories WHERE id = ? AND trip_id = ?',
  ).bind(memoryId, trip.id).all();
  const memory = results[0];
  if (!memory) return notFound('Memory not found');

  await env.DB.prepare(
    'DELETE FROM memories WHERE id = ? AND trip_id = ?',
  ).bind(memoryId, trip.id).run();
  if (memory.media_key) {
    await env.R2.delete(memory.media_key);
  }
  return json({ ok: true });
}

async function handlePutSong(env, code, body) {
  const trip = await tripByCode(env, code);
  if (!trip) return notFound('Trip not found');

  const title = String(body.title || '').slice(0, 200);
  const styleId = String(body.styleId || '').slice(0, 80);
  const audioAsset = String(body.audioAsset || '').slice(0, 200);
  if (title.length === 0 || styleId.length === 0 || audioAsset.length === 0) {
    return badRequest('title, styleId and audioAsset are required');
  }
  const bpm = Number.isInteger(body.bpm) ? body.bpm : 0;
  const durationMs = Number.isInteger(body.durationMs) ? body.durationMs : 0;
  if (bpm <= 0 || durationMs <= 0) {
    return badRequest('bpm and durationMs must be positive integers');
  }
  const lyrics = Array.isArray(body.lyrics)
    ? body.lyrics.map((l) => String(l).slice(0, 500)).filter((l) => l.length > 0)
    : [];
  const sections = Array.isArray(body.sections)
    ? body.sections.map((s) => ({
        id: String(s.id || '').slice(0, 80),
        label: String(s.label || '').slice(0, 120),
        kind: String(s.kind || '').slice(0, 40),
        startMs: Number.isInteger(s.startMs) ? s.startMs : 0,
        endMs: Number.isInteger(s.endMs) ? s.endMs : 0,
        lines: Array.isArray(s.lines)
          ? s.lines.map((l) => ({
              text: String(l.text || '').slice(0, 500),
              startMs: Number.isInteger(l.startMs) ? l.startMs : 0,
            }))
          : [],
      }))
    : [];

  const song = { title, styleId, bpm, audioAsset, durationMs, lyrics, sections };
  await env.DB.prepare('UPDATE trips SET song = ? WHERE id = ?')
    .bind(JSON.stringify(song), trip.id)
    .run();
  return json(song, 200);
}

async function handleGetSong(env, code) {
  const trip = await tripByCode(env, code);
  if (!trip) return notFound('Trip not found');
  const song = songFromRow(trip);
  if (!song) return notFound('This trip has no song yet');
  return json(song);
}

async function readJson(request) {
  try {
    return await request.json();
  } catch (_) {
    return null;
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Trip creation (creator app): POST /api/trips
    if (path === '/api/trips' && request.method === 'POST') {
      return handleCreateTrip(env, await readJson(request));
    }

    // API routes.
    const apiMatch = path.match(/^\/api\/trip\/([^/]+)(?:\/(.*))?$/);
    if (apiMatch) {
      const code = decodeURIComponent(apiMatch[1]);
      const rest = apiMatch[2] || '';

      if (rest === '' && request.method === 'GET') {
        return handleGetTrip(env, code);
      }
      if (rest === 'upload-url' && request.method === 'POST') {
        return handleUploadUrl(env, code, await readJson(request));
      }
      if (rest === 'memories' && request.method === 'POST') {
        return handleCreateMemory(env, code, await readJson(request));
      }
      if (rest === 'song' && request.method === 'PUT') {
        return handlePutSong(env, code, await readJson(request));
      }
      if (rest === 'song' && request.method === 'GET') {
        return handleGetSong(env, code);
      }
      const mediaMatch = rest.match(/^media\/([^/]+)$/);
      if (mediaMatch && request.method === 'GET') {
        return handleGetMedia(env, code, decodeURIComponent(mediaMatch[1]));
      }
      const deleteMatch = rest.match(/^memories\/([^/]+)$/);
      if (deleteMatch && request.method === 'DELETE') {
        return handleDeleteMemory(env, code, decodeURIComponent(deleteMatch[1]));
      }
      return methodNotAllowed();
    }

    // Everything else is static assets (the Flutter web build); the
    // not_found_handling = "single-page-application" config serves index.html
    // for /t/<code> so the SPA guest route can read the code from the URL.
    return env.ASSETS.fetch(request);
  },
};
