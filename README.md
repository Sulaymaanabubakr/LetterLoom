# LetterLoom

A complete, production-ready, offline-first Scrabble-style mobile game built with Flutter and Dart. 

Featuring a premium, tactile physical board-game design styled in rich forest green, warm ivory, and gold highlights, **LetterLoom** lets you play matches against an advanced computer opponent completely offline.

---

## 🎨 Visual Identity & Theme
- **Primary Color Scheme:** Deep Forest Green (`#0F382B`), Rich Emerald (`#1C5C44`), and Soft Warm Ivory (`#F7F5F0`).
- **Premium Cells:** DL (Double Letter - Pastel Blue), TL (Triple Letter - Medium Blue), DW (Double Word - Coral), TW (Triple Word - Terracotta).
- **Physical Tiles:** Tactile Ivory-style surfaces with gold typography, physical bottom bevel offsets, and soft drop shadows to resemble premium wooden game pieces.

---

## 🚀 Key Features
- **Independent Rules Engine:** Enforces all standard word-placement rules (center crossing, linear placements, connectivity, gap detection, crossword combinations, blank tiles, and endgame scoring rack deductions).
- **Offline Dictionary Service:** Bundles the ~172,000 word SOWPODS/enable1 English dictionary list directly into assets. Performs instant exact validation in $O(1)$ time and prefix checks in $O(\log N)$ time using a binary search index.
- **Isolate-Powered AI Opponent:** Offloads computer word search backtracking calculations to a background Dart Isolate to ensure smooth UI performance. Supports 3 distinct difficulties:
  - **Easy:** Prefers shorter words, skips premium squares, and chooses low-scoring plays.
  - **Medium:** Competes balancedly, scans multiple anchors, and targets mid-tier points.
  - **Hard:** Backtracks full anchors using prefix pruning, targets premium cells, and hunts for 50-point bingo bonuses.
- **Offline Save & Auto-Resume:** Game state is persisted locally to a JSON file after every turn. Handles corrupted save recovery gracefully without crashing.
- **Interactive Board Layout:** Uses a responsive board grid wrapping an `InteractiveViewer` supporting pan and pinch-to-zoom on smaller screens. Offers both Drag-and-Drop and Tap-to-Place interactions.

---

## 📂 Project Architecture

```
lib/
├── main.dart                      # App entrypoint and Splash screen dictionary loader
├── core/
│   ├── haptic_utils.dart          # Native haptic vibration triggers
│   └── sound_manager.dart         # Native system sound trigger click utilities
├── models/
│   ├── board_cell.dart            # Multipliers and tiles placement cell states
│   ├── game_settings.dart         # sound, haptic, and animation speed preferences
│   ├── game_state.dart            # Board, racks, bags, history, and status container
│   ├── move_history.dart          # Turn log items
│   ├── statistics.dart            # Games played, wins, losses, win rates, high scores
│   └── tile.dart                  # ID, point values, blank selection representations
├── game_engine/
│   ├── game_config.dart           # Letter distributions, values, and premium coordinate layouts
│   └── rules_validator.dart       # Alignment, adjacency, scoring, and bonus calculations
├── dictionary/
│   └── dictionary_service.dart    # Raw word list parsing, contains() and prefix search
├── ai/
│   ├── ai_engine.dart             # Backtracking interval candidate move compiler
│   └── ai_isolate.dart            # Background Spawn Isolate task with cancel support
├── storage/
│   └── persistence_manager.dart   # JSON file reader/writers for board, settings, and statistics
├── theme/
│   └── app_theme.dart             # Material 3 colors, text styles, and tile bevel decorations
├── features/
│   ├── home/                      # Main Menu view with difficulty selections
│   ├── game/                      # Draggable/clickable Gameplay view & blank tile picker
│   ├── settings/                  # Toggles for sounds and statistics reset confirmation
│   ├── statistics/                # Stats dashboard split by difficulty
│   └── how_to_play/               # Rules and tile point mapping guides
test/
├── game_engine_test.dart          # Unit tests for scoring, first moves, gaps, and bingos
├── persistence_test.dart          # Serialization checks for GameState conversions
├── ai_engine_test.dart            # AI legality, rack boundary, and pass calculations
└── widget_test.dart               # Widget test checking HomeScreen buttons
```

---

## 🛠️ Setup & Running

### Prerequisites
- Flutter SDK (v3.44.6 or later)
- Android SDK / Xcode for mobile simulation

### Get Dependencies
```bash
flutter pub get
```

### Run Tests
To run the automated unit and widget test suite:
```bash
flutter test
```

### Run Project
Launch the game on a connected emulator or device (the local Supabase values are read from the ignored `dart_defines.json` file):
```bash
flutter run --dart-define-from-file=dart_defines.json
```

### Build for Google Play

The release signing files are kept locally and ignored by Git. Generate the
Play Store bundle with:

```bash
flutter build appbundle --release \
  --dart-define-from-file=dart_defines.json
```

The bundle is written to
`build/app/outputs/bundle/release/app-release.aab`.

---

## 📜 Attributions & Licensing
- The offline dictionary uses the public domain **Enhanced North American Benchmark LExicon (ENABLE1)** word list.
- Ambient user interactions utilize native platform haptics and system sound clicks to eliminate asset load overhead.
