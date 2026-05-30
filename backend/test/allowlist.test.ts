import { test } from 'node:test';
import assert from 'node:assert/strict';
import { KID_SAFE_LABELS, filterAllowlist } from '../api/lib/allowlist.js';

test('allowlist contains a sensible spread of kid-safe labels', () => {
  // Anchor a few examples per category we care about, so an accidental
  // mass-removal would fail loudly.
  for (const must of ['dragon', 'cat', 'rocket', 'wizard', 'turtle']) {
    assert.ok(KID_SAFE_LABELS.has(must), `${must} should be allowlisted`);
  }
});

test('filterAllowlist drops anything not in the set', () => {
  const items = [
    { label: 'dragon', confidence: 0.6 },
    { label: 'knife', confidence: 0.9 },
    { label: 'cat', confidence: 0.5 },
    { label: 'gun', confidence: 0.95 },
  ];
  const kept = filterAllowlist(items).map(i => i.label).sort();
  assert.deepEqual(kept, ['cat', 'dragon']);
});

test('filterAllowlist is case-insensitive and trims', () => {
  const items = [
    { label: '  DRAGON  ', confidence: 0.6 },
    { label: 'Cat', confidence: 0.5 },
  ];
  assert.equal(filterAllowlist(items).length, 2);
});

test('filterAllowlist on an empty list returns an empty list', () => {
  assert.deepEqual(filterAllowlist([]), []);
});
