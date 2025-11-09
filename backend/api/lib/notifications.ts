import { RegionalActivity } from './redis';

// Notification thresholds
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

export function getNotificationMessage(
  category: string,
  count: number,
  region: string
): NotificationMessage {
  switch (category) {
    case 'animals':
      if (count > 20) {
        return {
          title: 'Animals Everywhere! 🦁☁️',
          body: `Lots of animal shapes spotted in ${region} clouds today!`,
        };
      } else {
        return {
          title: 'Animal Sightings! 🐻',
          body: `People are finding animal drawings in ${region} - look up!`,
        };
      }

    case 'mythical':
      if (count > 15) {
        return {
          title: 'Magical Skies! 🐉✨',
          body: `Dragons and unicorns appearing in ${region} clouds!`,
        };
      } else {
        return {
          title: 'Mythical Creatures! 🦄',
          body: `Magical beings spotted in the clouds near you!`,
        };
      }

    case 'landmarks':
      return {
        title: 'Architectural Wonders! 🗼',
        body: `Famous landmarks forming in ${region} clouds!`,
      };

    case 'vehicles':
      return {
        title: 'Sky Traffic! ✈️',
        body: `Vehicles and aircraft appearing in ${region} skies!`,
      };

    case 'food':
      return {
        title: 'Tasty Clouds! 🍕',
        body: `Delicious shapes forming in ${region} - take a look!`,
      };

    case 'nature':
      return {
        title: 'Natural Beauty! 🌸',
        body: `Beautiful nature patterns in ${region} clouds!`,
      };

    default:
      return {
        title: 'Cloud Watching Time! ☁️',
        body: `Perfect conditions in ${region} - others finding amazing shapes!`,
      };
  }
}

export function getGeneralActivityMessage(
  totalCount: number,
  region: string
): NotificationMessage {
  if (totalCount > 50) {
    return {
      title: 'Amazing Cloud Day! 🌤️',
      body: `${totalCount} drawings found in ${region} today - don't miss out!`,
    };
  } else if (totalCount > 30) {
    return {
      title: 'Active Sky Watching! ☁️',
      body: `People in ${region} are spotting great clouds right now!`,
    };
  } else {
    return {
      title: 'Cloud Watching Weather! 🌤️',
      body: `Perfect conditions in ${region} - look at the sky!`,
    };
  }
}

export function checkThresholds(activity: RegionalActivity): {
  category?: string;
  message?: NotificationMessage;
} {
  // Check each category
  for (const [category, count] of Object.entries(activity.categories)) {
    const threshold = THRESHOLDS[category as keyof typeof THRESHOLDS] || 10;

    if (count >= threshold) {
      return {
        category,
        message: getNotificationMessage(category, count, activity.region),
      };
    }
  }

  // Check total threshold
  if (activity.totalScans >= THRESHOLDS.total) {
    return {
      category: 'total',
      message: getGeneralActivityMessage(activity.totalScans, activity.region),
    };
  }

  return {};
}
