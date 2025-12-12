// This script generates the app icon programmatically.
// Run with: dart run scripts/generate_icon.dart

import 'dart:io';

// Creates a simple placeholder icon - for a real app, use a design tool.
// The app_icon.png should be 1024x1024 for best results.

void main() async {
  print('''
╔══════════════════════════════════════════════════════════════════════════════╗
║                         InvTracker App Icon Setup                            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  To generate app icons for InvTracker:                                       ║
║                                                                              ║
║  1. CREATE YOUR ICON:                                                        ║
║     • Use Figma, Canva, or any design tool                                   ║
║     • Size: 1024x1024 pixels (PNG with transparency)                         ║
║     • Design suggestion:                                                     ║
║       - Background: Gradient from #6C63FF to #5B4CDB (purple)                ║
║       - Icon: White chart/trending-up icon or "IT" monogram                  ║
║       - Style: Rounded corners (for Android adaptive icon)                   ║
║                                                                              ║
║  2. SAVE YOUR ICONS:                                                         ║
║     • Save full icon as: assets/icons/app_icon.png                           ║
║     • For Android adaptive icon (foreground only):                           ║
║       Save as: assets/icons/app_icon_foreground.png                          ║
║       (Icon centered with padding, transparent background)                   ║
║                                                                              ║
║  3. GENERATE ICONS FOR ALL PLATFORMS:                                        ║
║     Run: flutter pub run flutter_launcher_icons                              ║
║                                                                              ║
║  DESIGN GUIDELINES:                                                          ║
║  • iOS: No transparency in background, use full 1024x1024                    ║
║  • Android: Use adaptive icon with separate foreground/background            ║
║  • Keep main content within center 70% for safe zone                         ║
║                                                                              ║
║  QUICK ICON OPTIONS:                                                         ║
║  1. Use https://www.figma.com/ (free) to design                              ║
║  2. Use https://iconkitchen.com/ for quick generation                        ║
║  3. Use https://makeappicon.com/ to resize existing icon                     ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
''');

  // Check if icon exists
  final iconFile = File('assets/icons/app_icon.png');
  if (await iconFile.exists()) {
    print('✅ app_icon.png found!');
    print('   Run: flutter pub run flutter_launcher_icons');
  } else {
    print('❌ app_icon.png not found');
    print('   Please create your icon and save it to: assets/icons/app_icon.png');
  }
  
  final foregroundFile = File('assets/icons/app_icon_foreground.png');
  if (await foregroundFile.exists()) {
    print('✅ app_icon_foreground.png found!');
  } else {
    print('⚠️  app_icon_foreground.png not found (optional for Android adaptive icons)');
    print('   If not provided, app_icon.png will be used for all icons.');
  }
}

