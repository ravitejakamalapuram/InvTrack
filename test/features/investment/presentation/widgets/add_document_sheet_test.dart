import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_document_sheet.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_security_service.dart';

void main() {
  late FakeFlutterSecureStorage fakeSecureStorage;
  late FakeLocalAuthentication fakeLocalAuth;
  late SharedPreferences prefs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    fakeSecureStorage = FakeFlutterSecureStorage();
    fakeLocalAuth = FakeLocalAuthentication();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        flutterSecureStorageProvider.overrideWithValue(fakeSecureStorage),
        localAuthProvider.overrideWithValue(fakeLocalAuth),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const AddDocumentSheet(
                    investmentId: 'test-investment-id',
                  ),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  group('AddDocumentSheet', () {
    group('Initial State', () {
      testWidgets('should display title', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Add Document'), findsOneWidget);
      });

      testWidgets('should display source buttons', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Camera'), findsOneWidget);
        expect(find.text('Select Files'), findsOneWidget);
      });

      testWidgets('should display source button subtitles', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Take a photo'), findsOneWidget);
        expect(find.text('PDFs, images, etc.'), findsOneWidget);
      });

      testWidgets('should display camera icon', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      });

      testWidgets('should display folder icon for file picker', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
      });
    });

    group('DocumentType', () {
      testWidgets('all document types have display names', (tester) async {
        for (final type in DocumentType.values) {
          expect(type.displayName, isNotEmpty);
          expect(type.displayName.length, lessThan(20));
        }
      });

      testWidgets('all document types have icons', (tester) async {
        for (final type in DocumentType.values) {
          expect(type.icon, isNotNull);
        }
      });

      testWidgets('all document types have colors', (tester) async {
        for (final type in DocumentType.values) {
          expect(type.color, isNotNull);
          expect(type.color, isNot(Colors.transparent));
        }
      });
    });
  });
}

