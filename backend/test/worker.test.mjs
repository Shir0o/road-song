/**
 * Minimal unit tests for the Worker's trip-code scope enforcement and
 * guardrails. Runs with `node --test` (no wrangler, no network): a fake D1
 * and fake R2 stand in for the bindings.
 *
 *   cd backend && node --test
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const worker = require('../src/index.js').default;

/** In-memory D1 stand-in with prepare().bind().all()/run(). */
function fakeD1(rows) {
  const tables = {
    trips: rows.trips || [],
    memories: rows.memories || [],
  };
  return {
    prepare(sql) {
      return {
        bind(...args) {
          return {
            async all() {
              const params = args;
              if (sql.includes('FROM trips WHERE code')) {
                const code = params[0];
                return {
                  results: tables.trips.filter((t) => t.code === code),
                };
              }
              if (sql.includes('FROM memories WHERE trip_id')) {
                const tripId = params[0];
                return {
                  results: tables.memories
                    .filter((m) => m.trip_id === tripId)
                    .sort((a, b) => a.created_at.localeCompare(b.created_at)),
                };
              }
              if (sql.includes('WHERE id = ? AND trip_id = ?')) {
                const [id, tripId] = params;
                return {
                  results: tables.memories.filter(
                    (m) => m.id === id && m.trip_id === tripId,
                  ),
                };
              }
              return { results: [] };
            },
            async run() {
              const params = args;
              if (sql.trimStart().startsWith('INSERT INTO trips')) {
                const [id, code, name, firstDay, lastDay, coverIndex, createdAt] =
                  params;
                tables.trips.push({
                  id, code, name, first_day: firstDay, last_day: lastDay,
                  cover_index: coverIndex, created_at: createdAt,
                });
              }
              if (sql.trimStart().startsWith('INSERT INTO memories')) {
                const [id, tripId, type, contributor, author, caption, text,
                  day, dayDate, locationName, latitude, longitude, mediaKey,
                  createdAt] = params;
                tables.memories.push({
                  id, trip_id: tripId, type, contributor, author, caption,
                  text, day, day_date: dayDate, location_name: locationName,
                  latitude, longitude, media_key: mediaKey, created_at: createdAt,
                });
              }
              if (sql.trimStart().startsWith('DELETE FROM memories')) {
                const [id, tripId] = params;
                const i = tables.memories.findIndex(
                  (m) => m.id === id && m.trip_id === tripId,
                );
                if (i !== -1) tables.memories.splice(i, 1);
              }
              return { success: true };
            },
          };
        },
      };
    },
  };
}

/** Fake R2 binding: head()/delete() over a key set. */
function fakeR2(keys) {
  const present = new Set(keys || []);
  return {
    async head(key) {
      return present.has(key) ? { key } : null;
    },
    async delete(key) {
      present.delete(key);
    },
  };
}

function makeEnv({ trips, memories, mediaKeys } = {}) {
  return {
    DB: fakeD1({ trips, memories }),
    R2: fakeR2(mediaKeys),
    R2_ACCOUNT_ID: 'acct',
    R2_ACCESS_KEY_ID: 'key',
    R2_SECRET_ACCESS_KEY: 'secret',
    R2_BUCKET_NAME: 'road-song-media',
    ASSETS: { async fetch() { return new Response('spa', { status: 200 }); } },
  };
}

const tripA = {
  id: 'trip-a', code: 'alpha', name: 'Alpha Trip',
  first_day: 'JUN 1', last_day: 'JUN 7', cover_index: 0,
  created_at: '2026-06-01T00:00:00.000Z',
};
const tripB = {
  id: 'trip-b', code: 'bravo', name: 'Bravo Trip',
  first_day: 'JUL 1', last_day: 'JUL 7', cover_index: 0,
  created_at: '2026-07-01T00:00:00.000Z',
};
const memoryA = {
  id: 'mem-a1', trip_id: 'trip-a', type: 'text', contributor: 'Maya',
  author: '@maya', caption: '', text: 'Alpha lore', day: 1, day_date: 'JUN 1',
  location_name: null, latitude: null, longitude: null, media_key: null,
  created_at: '2026-06-01T10:00:00.000Z',
};

function api(env, method, path, body) {
  return worker.fetch(
    new Request(`https://road-song.test${path}`, {
      method,
      headers: { 'content-type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    }),
    env,
  );
}

test('POST /api/trips creates a trip with a unique code', async () => {
  const env = makeEnv({ trips: [tripA] });
  const res = await api(env, 'POST', '/api/trips', {
    name: 'Lisbon Trip', firstDay: 'JUN 12', lastDay: 'JUN 18', coverIndex: 1,
  });
  assert.equal(res.status, 201);
  const body = await res.json();
  assert.match(body.code, /^lisbon-trip-[0-9a-f]{4}$/);
  assert.equal(body.name, 'Lisbon Trip');
  assert.equal(body.memories.length, 0);

  // The new trip is fetchable by its code.
  const fetched = await api(env, 'GET', `/api/trip/${body.code}`);
  assert.equal(fetched.status, 200);
  assert.equal((await fetched.json()).name, 'Lisbon Trip');
});

test('GET /api/trip/:code returns the trip and its memories', async () => {
  const env = makeEnv({ trips: [tripA, tripB], memories: [memoryA] });
  const res = await api(env, 'GET', '/api/trip/alpha');
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.name, 'Alpha Trip');
  assert.equal(body.memories.length, 1);
  assert.equal(body.memories[0].text, 'Alpha lore');
});

test('unknown trip code is 404', async () => {
  const env = makeEnv({ trips: [tripA] });
  const res = await api(env, 'GET', '/api/trip/nope');
  assert.equal(res.status, 404);
});

test('cross-trip memory lookup is denied (404, not data)', async () => {
  const env = makeEnv({ trips: [tripA, tripB], memories: [memoryA] });
  // mem-a1 belongs to trip-a; asking for it under trip-b's code must 404.
  const res = await api(env, 'GET', '/api/trip/bravo/media/mem-a1');
  assert.equal(res.status, 404);
  // And under the right code it resolves.
  const ok = await api(env, 'GET', '/api/trip/alpha/media/mem-a1');
  assert.equal(ok.status, 404); // text memory has no media_key
});

test('cross-trip delete is denied', async () => {
  const env = makeEnv({ trips: [tripA, tripB], memories: [memoryA] });
  const res = await api(env, 'DELETE', '/api/trip/bravo/memories/mem-a1');
  assert.equal(res.status, 404);
  const stillThere = await api(env, 'GET', '/api/trip/alpha');
  assert.equal((await stillThere.json()).memories.length, 1);
});

test('upload-url rejects oversized bodies with 413', async () => {
  const env = makeEnv({ trips: [tripA] });
  const photo = await api(env, 'POST', '/api/trip/alpha/upload-url', {
    type: 'photo', contentType: 'image/jpeg',
    contentLength: 12 * 1024 * 1024 + 1,
  });
  assert.equal(photo.status, 413);
  const video = await api(env, 'POST', '/api/trip/alpha/upload-url', {
    type: 'video', contentType: 'video/mp4',
    contentLength: 64 * 1024 * 1024 + 1,
  });
  assert.equal(video.status, 413);
});

test('upload-url mints a presigned PUT for an in-limit file', async () => {
  const env = makeEnv({ trips: [tripA] });
  const res = await api(env, 'POST', '/api/trip/alpha/upload-url', {
    type: 'photo', contentType: 'image/jpeg', contentLength: 1000,
  });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.match(body.uploadUrl, /^https:\/\/acct\.r2\.cloudflarestorage\.com\//);
  assert.match(body.uploadUrl, /X-Amz-Signature=/);
  assert.match(body.mediaKey, /^trips\/trip-a\/[0-9a-f-]+\.jpeg$/);
});

test('create memory rejects a mediaKey from another trip', async () => {
  const env = makeEnv({ trips: [tripA, tripB], mediaKeys: ['trips/trip-b/x.jpg'] });
  const res = await api(env, 'POST', '/api/trip/alpha/memories', {
    type: 'photo', mediaKey: 'trips/trip-b/x.jpg', contributor: 'Maya',
  });
  assert.equal(res.status, 400);
});

test('create memory requires the media object to exist in R2', async () => {
  const env = makeEnv({ trips: [tripA], mediaKeys: [] });
  const res = await api(env, 'POST', '/api/trip/alpha/memories', {
    type: 'photo', mediaKey: 'trips/trip-a/missing.jpg', contributor: 'Maya',
  });
  assert.equal(res.status, 400);
});

test('create text memory succeeds and is scoped to the trip', async () => {
  const env = makeEnv({ trips: [tripA, tripB] });
  const res = await api(env, 'POST', '/api/trip/alpha/memories', {
    type: 'text', contributor: 'Priya', author: '@priya', text: 'New lore',
  });
  assert.equal(res.status, 201);
  const created = await res.json();
  assert.equal(created.text, 'New lore');
  assert.equal(created.contributor, 'Priya');

  // It appears under alpha, never under bravo.
  const alpha = await (await api(env, 'GET', '/api/trip/alpha')).json();
  assert.equal(alpha.memories.length, 1);
  const bravo = await (await api(env, 'GET', '/api/trip/bravo')).json();
  assert.equal(bravo.memories.length, 0);
});

test('non-API paths fall through to static assets (SPA)', async () => {
  const env = makeEnv({ trips: [tripA] });
  const res = await worker.fetch(
    new Request('https://road-song.test/t/alpha'),
    env,
  );
  assert.equal(res.status, 200);
  assert.equal(await res.text(), 'spa');
});
