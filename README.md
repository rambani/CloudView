# CloudView 🌤️✨

An innovative AR iOS app that brings clouds to life! Point your phone at the sky, and watch as AI transforms cloud shapes into delightful hand-drawn animations - like a turtle on a skateboard, a dragon eating burgers, or a surfing penguin!

## Features

### 🎨 AI-Powered Cloud Drawings
- **Smart Cloud Detection**: Uses Vision framework to detect cloud shapes in real-time
- **Creative Illustrations**: 12+ unique, cute, and funny hand-drawn concepts
- **Animated Drawing**: Lines slowly trace out over 2-3 seconds for a magical effect
- **Shape Matching**: AI intelligently matches cloud shapes to appropriate drawings

### 🌍 Persistent AR Experience
- **Constellation Effect**: Drawings stay anchored in the sky as you move around
- **Explore Freely**: Pan to different clouds and discover new drawings
- **Session Memory**: All drawings persist until you close the app

### ☀️ Weather Integration
- **Real-time Weather**: Current conditions, temperature, and humidity
- **Hourly Forecast**: Next 6 hours of weather predictions
- **Beautiful UI**: Clean, glassmorphic design with weather emojis
- **Location-based**: Automatic weather for your current location

### 🎯 Kid-Friendly & Appropriate
- All drawings are cute, funny, and family-friendly
- Perfect for sparking creativity and imagination
- Educational weather information

## Modular Drawing System

The app uses an **advanced modular component system** that creates virtually unlimited unique combinations:

### 🎭 Subjects (100+ options)

**Animals:**
- **Domestic**: Cat, Dog, Hamster, Rabbit, Parrot, Goldfish, Turtle
- **Farm**: Cow, Pig, Sheep, Chicken, Horse, Duck, Goat, Llama
- **Wild**: Lion, Tiger, Elephant, Giraffe, Zebra, Monkey, Panda, Koala, Kangaroo, Sloth
- **Ocean**: Dolphin, Whale, Octopus, Starfish, Crab, Seahorse, Jellyfish, Penguin, Seal, Otter
- **Arctic**: Polar Bear, Arctic Fox, Walrus, Reindeer, Snow Owl
- **Desert**: Camel, Meerkat, Snake, Scorpion, Lizard
- **Forest**: Bear, Deer, Fox, Owl, Squirrel, Raccoon, Hedgehog, Beaver
- **Insects**: Butterfly, Ladybug, Bee, Caterpillar, Snail, Dragonfly

**Mythical Creatures:**
- Unicorn, Dragon, Phoenix, Pegasus, Griffin, Fairy, Mermaid, Yeti

**Dinosaurs:**
- T-Rex, Triceratops, Brontosaurus, Stegosaurus, Pterodactyl, Velociraptor

**People & Professions:**
- Astronaut, Chef, Artist, Scientist, Firefighter, Teacher, Doctor, Musician, Athlete, Explorer

**World Landmarks:**
- Pyramid, Eiffel Tower, Big Ben, Statue of Liberty, Taj Mahal, Great Wall, Colosseum, Christ the Redeemer

**Vehicles:**
- Car, Airplane, Boat, Submarine, Hot Air Balloon, Rocket, Train, Bicycle, Scooter, Helicopter

**Food Characters:**
- Apple, Banana, Pizza, Donut, Cupcake, Ice Cream, Cookie, Watermelon, Strawberry, Taco

**Nature & Fantasy:**
- Sun, Moon, Star, Cloud, Rainbow, Tree, Flower, Mountain, Volcano
- Castle, Treasure, Magic Wand, Crown, Crystal Ball, Flying Carpet

**Tech:**
- Robot, Computer, Satellite, Drone

### 🎯 Actions (70+ activities)

**Sports:**
- Skateboarding, Surfing, Skiing, Snowboarding, Rollerblading
- Playing Basketball/Soccer/Tennis/Baseball/Golf
- Swimming, Diving, Sailing, Kayaking, Paddleboarding
- Cycling, Running, Jumping, Dancing, Gymnastics

**Arts & Creativity:**
- Painting, Drawing, Playing Guitar/Piano/Drums, Singing
- Sculpting, Photography, Writing, Reading

**Everyday Activities:**
- Cooking, Baking, Gardening, Fishing, Camping
- Flying Kite, Blowing Bubbles, Playing Chess, Juggling

**Adventure & Exploration:**
- Exploring, Climbing, Hiking, Treasure Hunting
- Space Exploring, Deep Sea Diving, Flying, Soaring
- Paragliding, Bungee Jumping, Ziplining

**Magical:**
- Casting Spells, Riding Broomstick, Granting Wishes, Breathing Fire

**Relaxing:**
- Sleeping, Meditating, Sunbathing, Stargazing, Cloud Watching
- Drinking Tea, Eating Snacks, Napping

**Playful:**
- Playing with Toys, Hopscotch, Hide and Seek
- Splashing in Puddles, Making Snow Angels, Catching Fireflies

**Work & Career:**
- Saving the Day, Performing Surgery, Conducting Experiments
- Teaching Class, Fighting Fire, Launching Rocket

### 🎩 Accessories (90+ items)

**Headwear**: Wizard Hat, Baseball Cap, Crown, Cowboy Hat, Party Hat, Chef Hat, Pirate Hat, Beret, Beanie

**Eyewear**: Sunglasses, Glasses, Goggles, Monocle, 3D Glasses, Heart Glasses

**Items**: Umbrella, Balloon, Kite, Telescope, Magnifying Glass, Camera, Paintbrush, Book, Map, Compass

**Sports Gear**: Skateboard, Surfboard, Skis, Snowboard, Bicycle, Basketball, Soccer Ball, Tennis Racket

**Musical**: Guitar, Drums, Piano, Trumpet, Violin, Ukulele

**Magical**: Crystal Ball, Spell Book, Potion Bottle, Magic Staff, Fairy Dust

**Fun**: Bubbles, Confetti, Flowers, Butterfly, Sparkles, Hearts, Stars, Rainbow

### 😊 Expressions (10 moods)
Happy, Excited, Silly, Peaceful, Determined, Curious, Sleepy, Joyful, Surprised, Cool

### 🎲 Total Combinations

With smart combination rules that ensure kid-safe, sensible pairings:
- **100+ subjects** × **70+ actions** × **90+ accessories** × **10 expressions**
- **= Millions of possible combinations!**
- **Repetition Prevention**: Tracks last 50 drawings to avoid repeats

### Example Combinations

- "Happy Penguin Surfing with Sunglasses and Balloon"
- "Silly Dragon Eating Snacks with Wizard Hat"
- "Excited Astronaut Exploring Space with Telescope and Flag"
- "Peaceful Unicorn Cloud Watching with Sparkles"
- "Cool T-Rex Playing Basketball with Baseball Cap"
- "Joyful Giraffe in Scarf Dancing with Hearts"

## Requirements

- iOS 16.0+
- iPhone with ARKit support (iPhone 6s or newer)
- Xcode 15.0+
- Swift 5.9+

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/CloudView.git
cd CloudView
```

### 2. Open in Xcode

```bash
open CloudView.xcodeproj
```

### 3. Configure Weather API (Optional)

To get real weather data instead of mock data:

1. Sign up for a free API key at [OpenWeatherMap](https://openweathermap.org/api)
2. Open `CloudView/Services/WeatherService.swift`
3. Replace `YOUR_API_KEY_HERE` with your actual API key:

```swift
private let apiKey = "your_actual_api_key_here"
```

4. In `ContentView.swift`, uncomment the real weather fetch:

```swift
// Replace this:
weatherService.useMockData()

// With this:
weatherService.requestLocationAndFetchWeather()
```

### 4. Build and Run

1. Select your iPhone as the target device (AR doesn't work in simulator)
2. Press `Cmd + R` to build and run
3. Allow camera and location permissions when prompted
4. Point your phone at the sky and watch the magic happen!

## How to Use

1. **Launch the app** on your iPhone
2. **Point at clouds** in the sky
3. **Hold still** for a few seconds
4. **Watch** as lines slowly draw a cute illustration over the cloud
5. **Pan around** to explore more clouds and create more drawings
6. **Check weather** at the bottom of the screen

## Technical Architecture

### Core Components

- **ARViewModel**: Manages AR session, cloud detection, and drawing placement
- **CloudDetector**: Uses Vision framework for cloud region detection
- **DrawingLibrary**: Collection of hand-drawn vector paths
- **AnimatedDrawing**: Handles line-by-line drawing animation
- **WeatherService**: Fetches current weather and forecasts
- **ARViewContainer**: SwiftUI wrapper for RealityKit ARView

### Technologies Used

- **ARKit**: World tracking and AR anchor management
- **RealityKit**: 3D rendering and entity management
- **Vision**: Cloud detection using contour and brightness analysis
- **CoreLocation**: Location services for weather
- **SwiftUI**: Modern declarative UI
- **Combine**: Reactive programming for weather data

### Drawing System

Each drawing is composed of:
- **Paths**: Series of CGPoints defining the shape
- **Animation Order**: Sequential drawing of each path
- **3D Mesh Generation**: Converts 2D paths to 3D line meshes
- **Progressive Animation**: Lines appear gradually over time

## Customization

### Adding New Subjects, Actions, or Accessories

The modular system makes it incredibly easy to expand:

1. **Add a New Subject:**
```swift
// In DrawingLibrary.swift, add to DrawingSubject enum:
enum DrawingSubject: String, CaseIterable {
    // ... existing subjects
    case yourNewAnimal // Add your new subject here
}
```

2. **Add a New Action:**
```swift
// Add to DrawingAction enum:
enum DrawingAction: String, CaseIterable {
    // ... existing actions
    case yourNewActivity // Add your new action here
}
```

3. **Add a New Accessory:**
```swift
// Add to DrawingAccessory enum:
enum DrawingAccessory: String, CaseIterable {
    // ... existing accessories
    case yourNewAccessory // Add your new accessory here
}
```

The system will automatically:
- Generate unique combinations
- Apply smart compatibility rules
- Create procedural drawings
- Avoid repetition

### Adjusting Detection Sensitivity

In `ARViewModel.swift`, modify:
- `processingInterval`: How often to process frames (default: 1.0 second)
- `requiredStableFrames`: How many frames before drawing (default: 15)

### Customizing Animation

In `AnimatedDrawing.swift`, adjust:
- `duration`: Total drawing animation time (default: 2.5 seconds)
- `lineWidth`: Thickness of drawn lines (default: 0.003 meters)

## Troubleshooting

### App crashes on launch
- Make sure you're running on a physical device, not simulator
- Check that ARKit is supported on your device

### No clouds detected
- Ensure you're pointing at actual clouds in the sky
- Try on a day with visible cloud coverage
- Make sure camera permissions are granted

### Weather not loading
- Check internet connection
- Verify location permissions are granted
- Add your own OpenWeatherMap API key (free tier available)

### Drawings appear in wrong location
- Hold phone steady while drawing is being created
- Point directly at clouds, not at horizon or ground

## Future Enhancements

Potential features for future versions:
- [ ] Save and share cloud drawings
- [ ] Social features (share with friends)
- [ ] More drawing concepts (100+ variations)
- [ ] Custom drawing creation
- [ ] Drawing gallery/history
- [ ] Time-lapse video recording
- [ ] Multiplayer (see friends' drawings)
- [ ] Achievement system
- [ ] Sound effects and music

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

- Developed with ARKit, RealityKit, and Vision
- Weather data from OpenWeatherMap
- Inspired by the beauty of clouds and childhood imagination

## Support

For questions or issues, please open an issue on GitHub.

---

Made with ☁️ and ❤️

Enjoy discovering magical creatures in the clouds!
