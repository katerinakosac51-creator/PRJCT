# Flutter Basic App

A basic Flutter application with a counter example.

## Project Structure

```
my_app/
├── lib/
│   └── main.dart           # Main app entry point
├── test/                   # Tests directory
├── pubspec.yaml            # Project dependencies and configuration
├── .gitignore              # Git ignore file
└── README.md               # This file
```

## Features

- Material Design UI
- Stateful widget example
- Counter that increments on button press
- Responsive layout

## Getting Started

### Prerequisites

- Install Flutter SDK: https://flutter.dev/docs/get-started/install
- Install a code editor (VS Code, Android Studio, or IntelliJ)
- Install Flutter and Dart plugins for your editor

### Setup Instructions

1. Navigate to the project directory:
   ```bash
   cd my_app
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

   For specific targets:
   ```bash
   flutter run -d chrome        # Web
   flutter run -d macos         # macOS
   flutter run -d windows       # Windows
   flutter run -d linux         # Linux
   ```

4. Build for release:
   ```bash
   flutter build apk            # Android
   flutter build ios            # iOS
   flutter build web            # Web
   ```

## App Walkthrough

The app consists of:

- **MyApp**: Root widget that configures MaterialApp with theme
- **MyHomePage**: Displays title and counter in AppBar
- **_MyHomePageState**: Manages counter state and UI updates

The floating action button increments the counter when tapped.

## Next Steps

- Modify the UI in `lib/main.dart`
- Add more pages and navigation
- Integrate packages from pub.dev
- Add local data persistence with shared_preferences or sqflite
- Create custom widgets

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Flutter API Reference](https://api.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Google Fonts for Flutter](https://pub.dev/packages/google_fonts)

## License

MIT License
