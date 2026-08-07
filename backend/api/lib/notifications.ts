import { RegionalActivity } from './redis';

// Notification thresholds. `animals` and `mythical` are the live categories
// for the current creature library (rabbit/fish/cat/bird/whale/turtle/swan/
// bear → animals, dragon → mythical); the rest are kept so older clients and
// future library expansions keep working without a backend deploy.
const THRESHOLDS = {
  animals: 20,
  mythical: 15,
  landmarks: 10,
  vehicles: 10,
  food: 10,
  nature: 10,
  total: 50,
};

export interface NotificationMessage {
  title: string;
  body: string;
}

// ---------------------------------------------------------------------------
// Seeded copy selection
//
// Copy is picked deterministically from a variant bank, seeded by
// (category, region, date). Same region + same day → the same message
// (consistent with the once-per-day dedupe upstream); a different day or a
// different city → different copy. No Math.random: deterministic copy is
// testable and reproducible from logs.
// ---------------------------------------------------------------------------

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

function pick<T>(variants: T[], seedKey: string): T {
  return variants[fnv1a(seedKey) % variants.length]!;
}

type CopyVariant = (region: string, count: number) => NotificationMessage;

const CATEGORY_COPY: Record<string, CopyVariant[]> = {
  animals: [
    (region, count) => ({
      title: 'The sky is full of animals! 🐋',
      body: `${count} cloud creatures spotted over ${region} today — look up and find yours.`,
    }),
    (region) => ({
      title: 'Animal clouds over your city 🐰',
      body: `People in ${region} keep finding animals in the sky right now. Step outside!`,
    }),
    (region) => ({
      title: 'A sky safari is happening ☁️',
      body: `Whales, bears, and bunnies are drifting over ${region} — grab a look before they change.`,
    }),
  ],
  mythical: [
    (region) => ({
      title: 'Dragons in the sky! 🐉',
      body: `Dragon-shaped clouds are gliding over ${region} — look up before they fly on.`,
    }),
    (region, count) => ({
      title: 'Magical skies today ✨',
      body: `${count} mythical sightings over ${region} so far — the clouds are in a storytelling mood.`,
    }),
    (region) => ({
      title: 'Something legendary overhead 🐲',
      body: `The clouds above ${region} have gone full fairy tale. Worth a look up.`,
    }),
  ],
  landmarks: [
    (region) => ({
      title: 'Castles in the clouds 🏰',
      body: `Towers and landmarks are forming over ${region} — the sky is building things today.`,
    }),
    (region) => ({
      title: 'Sky architecture spotted 🗼',
      body: `People near ${region} are seeing famous shapes in the clouds. Take a look!`,
    }),
  ],
  vehicles: [
    (region) => ({
      title: 'Sky traffic over your city ✈️',
      body: `Cloud ships and planes drifting over ${region} — look up between the real ones.`,
    }),
    (region) => ({
      title: 'Cloud convoy passing through 🚂',
      body: `Vehicle-shaped clouds cruising over ${region} right now.`,
    }),
  ],
  food: [
    (region) => ({
      title: 'Delicious-looking sky 🍦',
      body: `Tasty cloud shapes floating over ${region} — best enjoyed by looking up.`,
    }),
    (region) => ({
      title: 'The clouds look like snacks 🍩',
      body: `People in ${region} keep spotting food in the sky today. See what you find.`,
    }),
  ],
  nature: [
    (region) => ({
      title: 'Beautiful cloud shapes 🌸',
      body: `The sky over ${region} is drawing lovely things today — take a look.`,
    }),
    (region) => ({
      title: 'Nature in the clouds 🌿',
      body: `Gorgeous formations over ${region} right now — a good moment to look up.`,
    }),
  ],
};

const DEFAULT_COPY: CopyVariant[] = [
  (region) => ({
    title: 'Cloud watching time ☁️',
    body: `Great cloud shapes over ${region} right now — others are finding amazing things.`,
  }),
  (region) => ({
    title: 'The sky is showing off ✨',
    body: `People near ${region} keep spotting shapes in the clouds. Join in!`,
  }),
];

const TOTAL_COPY: CopyVariant[] = [
  (region, count) => ({
    title: 'Big cloud day! 🌤️',
    body: `${count} drawings found over ${region} today — the sky is on a roll.`,
  }),
  (region) => ({
    title: 'Everyone is looking up ☁️',
    body: `${region} is having a great sky day — see what the clouds have for you.`,
  }),
  (region, count) => ({
    title: 'The clouds are busy today ✏️',
    body: `${count} sightings over ${region} and counting. Yours is up there somewhere.`,
  }),
];

export function getNotificationMessage(
  category: string,
  count: number,
  region: string,
  seedKey = '',
): NotificationMessage {
  const variants = CATEGORY_COPY[category] ?? DEFAULT_COPY;
  return pick(variants, `${category}:${region}:${seedKey}`)(region, count);
}

export function getGeneralActivityMessage(
  totalCount: number,
  region: string,
  seedKey = '',
): NotificationMessage {
  return pick(TOTAL_COPY, `total:${region}:${seedKey}`)(region, totalCount);
}

export interface ThresholdHit {
  category: string;
  count: number;
  message: NotificationMessage;
}

/**
 * Returns every category that has crossed its threshold for the day.
 * The caller is responsible for per-(region,date,category) dedupe so we
 * don't send the same notification twice. Copy is seeded by the activity's
 * date so each day's notification reads differently.
 */
export function checkThresholds(activity: RegionalActivity): ThresholdHit[] {
  const hits: ThresholdHit[] = [];

  for (const [category, count] of Object.entries(activity.categories)) {
    const threshold = THRESHOLDS[category as keyof typeof THRESHOLDS] ?? 10;
    if (count >= threshold) {
      hits.push({
        category,
        count,
        message: getNotificationMessage(category, count, activity.region, activity.date),
      });
    }
  }

  if (activity.totalScans >= THRESHOLDS.total) {
    hits.push({
      category: 'total',
      count: activity.totalScans,
      message: getGeneralActivityMessage(activity.totalScans, activity.region, activity.date),
    });
  }

  return hits;
}
