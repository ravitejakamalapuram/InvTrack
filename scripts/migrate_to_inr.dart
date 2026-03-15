#!/usr/bin/env dart
// One-time migration script to set base currency to INR for all users
// and update all cashflows to INR currency
//
// Usage: dart run scripts/migrate_to_inr.dart
//
// ⚠️  WARNING: This is a one-time migration script!
// It will update ALL users' base currency to INR and set all cashflows/investments to INR.
// Make sure you have a backup before running this!

// ignore_for_file: avoid_print, avoid_relative_lib_imports

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

Future<void> main() async {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('⚠️  INR MIGRATION SCRIPT');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('This will update ALL users to use INR as base currency');
  print('and set all cashflows/investments to INR currency.');
  print('');
  print('Are you sure you want to continue? (yes/no)');

  final confirmation = stdin.readLineSync();
  if (confirmation?.toLowerCase() != 'yes') {
    print('❌ Migration cancelled.');
    exit(0);
  }

  print('\n🚀 Starting migration to INR...\n');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final firestore = FirebaseFirestore.instance;

  try {
    // Step 1: Get all users
    print('📋 Step 1: Fetching all users...');
    final usersSnapshot = await firestore.collection('users').get();
    print('   Found ${usersSnapshot.docs.length} users\n');

    int userProfilesUpdated = 0;
    int cashflowsUpdated = 0;
    int investmentsUpdated = 0;

    // Step 2: Update each user
    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      print('👤 Processing user: $userId');

      // Update user profile - set base currency to INR
      final userProfileRef = firestore.collection('users').doc(userId);
      final userProfileData = userDoc.data();
      
      if (userProfileData['currencyCode'] != 'INR') {
        await userProfileRef.update({
          'currencyCode': 'INR',
          'currencySymbol': '₹',
          'locale': 'en_IN',
        });
        userProfilesUpdated++;
        print('   ✅ Updated user profile to INR');
      } else {
        print('   ⏭️  User already using INR');
      }

      // Update all cashflows for this user
      final cashflowsRef = firestore
          .collection('users')
          .doc(userId)
          .collection('cashflows');
      
      final cashflowsSnapshot = await cashflowsRef.get();
      
      if (cashflowsSnapshot.docs.isNotEmpty) {
        final batch = firestore.batch();
        int batchCount = 0;

        for (final cashflowDoc in cashflowsSnapshot.docs) {
          final data = cashflowDoc.data();
          
          // Only update if currency is not already INR
          if (data['currency'] != 'INR') {
            batch.update(cashflowDoc.reference, {'currency': 'INR'});
            batchCount++;
            cashflowsUpdated++;
          }
        }

        if (batchCount > 0) {
          await batch.commit();
          print('   ✅ Updated $batchCount cashflows to INR');
        } else {
          print('   ⏭️  All cashflows already in INR');
        }
      }

      // Update all investments for this user
      final investmentsRef = firestore
          .collection('users')
          .doc(userId)
          .collection('investments');
      
      final investmentsSnapshot = await investmentsRef.get();
      
      if (investmentsSnapshot.docs.isNotEmpty) {
        final batch = firestore.batch();
        int batchCount = 0;

        for (final investmentDoc in investmentsSnapshot.docs) {
          final data = investmentDoc.data();
          
          // Only update if currency is not already INR
          if (data['currency'] != 'INR') {
            batch.update(investmentDoc.reference, {'currency': 'INR'});
            batchCount++;
            investmentsUpdated++;
          }
        }

        if (batchCount > 0) {
          await batch.commit();
          print('   ✅ Updated $batchCount investments to INR');
        } else {
          print('   ⏭️  All investments already in INR');
        }
      }

      print('');
    }

    // Summary
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('✅ Migration completed successfully!');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 Summary:');
    print('   • User profiles updated: $userProfilesUpdated');
    print('   • Cashflows updated: $cashflowsUpdated');
    print('   • Investments updated: $investmentsUpdated');
    print('   • Total users processed: ${usersSnapshot.docs.length}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  } catch (e, stackTrace) {
    print('❌ Error during migration: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }

  exit(0);
}

