// Kid-safe label allowlist. Vision-model output that doesn't appear here
// is dropped before it ever reaches the user. The list is intentionally
// finite and reviewable — additions are a deliberate choice, not implicit.

export const KID_SAFE_LABELS = new Set<string>([
  // Domestic + cozy animals
  'cat', 'dog', 'rabbit', 'hamster', 'mouse', 'bird', 'duck',
  'turtle', 'fish', 'frog',

  // Wild + zoo
  'lion', 'tiger', 'elephant', 'giraffe', 'zebra', 'monkey', 'panda',
  'koala', 'kangaroo', 'sloth', 'bear', 'fox', 'deer', 'owl',
  'squirrel', 'raccoon', 'hedgehog',

  // Ocean
  'dolphin', 'whale', 'octopus', 'starfish', 'crab', 'seahorse',
  'jellyfish', 'penguin', 'seal', 'otter', 'shark',

  // Mythical
  'unicorn', 'dragon', 'phoenix', 'pegasus', 'griffin', 'fairy',
  'mermaid', 'wizard', 'witch', 'ghost', 'centaur',

  // Dinosaurs
  't-rex', 'triceratops', 'brontosaurus', 'stegosaurus', 'pterodactyl',

  // People + roles (kid-positive only)
  'astronaut', 'pirate', 'knight', 'chef', 'artist', 'firefighter',
  'doctor', 'musician', 'explorer',

  // Vehicles
  'car', 'airplane', 'boat', 'submarine', 'hot air balloon', 'rocket',
  'train', 'bicycle', 'helicopter', 'spaceship',

  // Food (the friendly kind)
  'pizza', 'donut', 'cupcake', 'ice cream', 'cookie', 'watermelon',
  'strawberry', 'banana', 'apple', 'taco',

  // Nature
  'sun', 'moon', 'star', 'rainbow', 'tree', 'flower', 'mountain',
  'volcano', 'cloud',

  // Fantasy objects
  'castle', 'treasure chest', 'magic wand', 'crown', 'crystal ball',
  'flying carpet', 'spell book',

  // Tech / playful
  'robot', 'computer', 'satellite', 'drone',

  // Sports / play
  'soccer ball', 'basketball', 'skateboard', 'surfboard',
  'kite', 'balloon',
]);

/**
 * Drop interpretations whose label isn't allowlisted. The vision model is
 * prompted to stay inside this list but we never trust prompt obedience —
 * this filter is the actual guarantee.
 */
export function filterAllowlist<T extends { label: string }>(items: T[]): T[] {
  return items.filter(i => KID_SAFE_LABELS.has(i.label.toLowerCase().trim()));
}
