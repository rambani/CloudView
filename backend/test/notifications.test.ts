import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  checkThresholds,
  getNotificationMessage,
  getGeneralActivityMessage,
} from '../api/lib/notifications.js';
import { endOfDayTtlSeconds } from '../api/lib/redis.js';
import type { RegionalActivity } from '../api/lib/redis.js';

const baseActivity: RegionalActivity = {
  region: 'San Francisco',
  date: '2026-05-29',
  categories: {},
  totalScans: 0,
  lastUpdated: '2026-05-29T12:00:00.000Z',
};

test('checkThresholds: no categories at threshold returns empty', () => {
  const hits = checkThresholds({
    ...baseActivity,
    categories: { animals: 5, vehicles: 3 },
    totalScans: 8,
  });
  assert.deepEqual(hits, []);
});

test('checkThresholds: one category crossed returns one hit', () => {
  const hits = checkThresholds({
    ...baseActivity,
    categories: { animals: 25 },
    totalScans: 25,
  });
  assert.equal(hits.length, 1);
  assert.equal(hits[0]!.category, 'animals');
  assert.equal(hits[0]!.count, 25);
});

test('checkThresholds: returns EVERY category over its threshold (regression fix)', () => {
  // Before the fix, the function returned on the first hit and silently
  // dropped notifications for other categories that had also crossed today.
  const hits = checkThresholds({
    ...baseActivity,
    categories: {
      animals: 25,    // > 20
      mythical: 16,   // > 15
      vehicles: 11,   // > 10
      food: 5,        // under
    },
    totalScans: 57,   // > 50 total threshold
  });
  const cats = hits.map(h => h.category).sort();
  assert.deepEqual(cats, ['animals', 'mythical', 'total', 'vehicles']);
});

test('checkThresholds: unknown category gets default threshold of 10', () => {
  const hits = checkThresholds({
    ...baseActivity,
    categories: { somethingNew: 10 },
    totalScans: 10,
  });
  assert.equal(hits.length, 1);
  assert.equal(hits[0]!.category, 'somethingNew');
});

test('copy: every category produces non-empty region-mentioning copy', () => {
  const categories = ['animals', 'mythical', 'landmarks', 'vehicles', 'food', 'nature', 'unknownFuture'];
  for (const category of categories) {
    const msg = getNotificationMessage(category, 25, 'Oakland', '2026-08-07');
    assert.ok(msg.title.length > 0, `${category}: empty title`);
    assert.ok(msg.body.includes('Oakland'), `${category}: body must mention the region: ${msg.body}`);
  }
  const total = getGeneralActivityMessage(60, 'Oakland', '2026-08-07');
  assert.ok(total.title.length > 0);
  assert.ok(total.body.includes('Oakland'));
});

test('copy: deterministic for same (category, region, date)', () => {
  const a = getNotificationMessage('animals', 25, 'Oakland', '2026-08-07');
  const b = getNotificationMessage('animals', 25, 'Oakland', '2026-08-07');
  assert.deepEqual(a, b);
});

test('copy: varies across days for the same region+category', () => {
  // With 3 variants, 10 consecutive days must hit at least 2 distinct
  // messages unless seeding is broken.
  const titles = new Set(
    Array.from({ length: 10 }, (_, i) =>
      getNotificationMessage('animals', 25, 'Oakland', `2026-08-${String(i + 1).padStart(2, '0')}`).title,
    ),
  );
  assert.ok(titles.size > 1, `expected variety across days, got only: ${[...titles]}`);
});

test('checkThresholds: copy is seeded by the activity date', () => {
  const day1 = checkThresholds({
    ...baseActivity,
    date: '2026-08-01',
    categories: { animals: 25 },
    totalScans: 25,
  });
  const day1again = checkThresholds({
    ...baseActivity,
    date: '2026-08-01',
    categories: { animals: 25 },
    totalScans: 25,
  });
  assert.deepEqual(day1, day1again, 'same day must produce identical copy');
});

test('endOfDayTtlSeconds: positive, less than 24h, at least 1h floor', () => {
  const ttl = endOfDayTtlSeconds();
  assert.ok(ttl > 0, 'TTL must be positive');
  assert.ok(ttl <= 86400, 'TTL must not exceed 24h');
  assert.ok(ttl >= 3600, 'TTL must have a 1h floor');
});
