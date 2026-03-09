import 'dart:io';

void main() {
  final file = File('lib/features/fire_number/presentation/screens/fire_setup_screen.dart');
  final content = file.readAsStringSync();
  print(content.contains('tooltip: \'Go back\''));
}
