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

## Drawing Library

The app includes these delightful concepts:

**Round Shapes:**
- Turtle on Skateboard
- Happy Sun with rays
- Sleeping Cat
- Bubble Tea Cup

**Elongated Shapes:**
- Dragon Eating Burger
- Dachshund in Sweater
- Surfing Penguin

**Wide Shapes:**
- Flying Saucer with alien
- Whale with Umbrella
- Cloud Castle

**Tall Shapes:**
- Giraffe in Scarf
- Rocket Ship with astronaut
- Ice Cream Cone with cherry

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

### Adding New Drawings

1. Open `CloudView/Models/DrawingLibrary.swift`
2. Create a new static function following this pattern:

```swift
static func createYourDrawing() -> DrawingConcept {
    DrawingConcept(
        name: "Your Drawing Name",
        paths: [
            DrawingPath(points: [
                CGPoint(x: 0.5, y: 0.5),
                // Add more points...
            ], closed: false, order: 1)
        ],
        preferredShape: .round // or .elongated, .wide, .tall
    )
}
```

3. Add it to the `drawings` array in the initializer

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
