1. **Add tooltips to `IconButton`s missing them.**
   - In `lib/features/fire_number/presentation/screens/fire_setup_screen.dart`, tooltips are missing on multiple `IconButton`s. However, wait, let me check the previous grep.
   - Wait, `fire_setup_screen.dart` has:
     ```
     icon: const Icon(Icons.arrow_back),
     onPressed: _previousStep,
     tooltip: 'Go back',
     ```
     My regex script was slightly off or I didn't interpret it right.
   - Ah, `find_no_tooltip.dart` found:
     - `fire_setup_screen.dart` (Wait, it DOES have tooltip in the code, my `find_no_tooltip.dart` captured only the first line maybe. `IconButton(\n      icon: ...\n   )`).
     - Let me check manually using grep.
