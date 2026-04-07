import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function to delete old anonymous users and their data.
 *
 * Runs daily at 2 AM UTC.
 * Deletes anonymous users inactive for 30+ days.
 * Deletes both Firestore data AND Firebase Auth user accounts.
 */
export const cleanupOldAnonymousUsers = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30); // 30 days ago

    functions.logger.info('Starting anonymous user cleanup', {
      cutoffDate: cutoffDate.toISOString(),
    });

    let deletedCount = 0;
    let errorCount = 0;

    // Paginate through all users (max 1000 per call)
    let pageToken: string | undefined;
    do {
      try {
        const listUsersResult = await admin.auth().listUsers(1000, pageToken);

        for (const user of listUsersResult.users) {
          // Check if user is anonymous (no provider data)
          if (user.providerData.length === 0) {
            // Use fallback chain: lastRefreshTime > lastSignInTime > creationTime
            const lastActivityIso =
              user.metadata.lastRefreshTime ??
              user.metadata.lastSignInTime ??
              user.metadata.creationTime;
            if (!lastActivityIso) continue;
            const lastActivity = new Date(lastActivityIso);
            if (Number.isNaN(lastActivity.getTime())) continue;

            if (lastActivity < cutoffDate) {
              try {
                // 1. Delete Firestore data
                await deleteUserData(user.uid);

                // 2. Delete Firebase Auth user (CRITICAL - prevents orphaned auth records)
                await admin.auth().deleteUser(user.uid);

                deletedCount++;
                functions.logger.info('Deleted anonymous user', {
                  uid: user.uid,
                  lastActivity: lastActivity.toISOString(),
                });
              } catch (error) {
                errorCount++;
                functions.logger.error('Failed to delete anonymous user', {
                  uid: user.uid,
                  error: error instanceof Error ? error.message : String(error),
                });
              }
            }
          }
        }

        pageToken = listUsersResult.pageToken;
      } catch (error) {
        functions.logger.error('Failed to list users', {
          error: error instanceof Error ? error.message : String(error),
        });
        break; // Stop pagination on error
      }
    } while (pageToken);

    functions.logger.info('Anonymous user cleanup complete', {
      deletedCount,
      errorCount,
    });

    return null;
  });

/**
 * Deletes all Firestore data for a user.
 *
 * Deletes all collections under users/{userId}/:
 * - investments
 * - cashflows
 * - goals
 * - archivedInvestments
 * - archivedCashflows
 * - archivedGoals
 * - documents
 * - fireSettings
 * - profile
 * - exchangeRates
 * - healthScores
 */
const MAX_RETRY_ATTEMPTS = 3;

async function deleteUserData(userId: string): Promise<void> {
  const firestore = admin.firestore();
  const bulkWriter = firestore.bulkWriter();

  // Register error handler for failed deletes
  bulkWriter.onWriteError((error) => {
    console.error('BulkWriter delete failed:', error);

    // Enforce max retry cap
    if (error.failedAttempts >= MAX_RETRY_ATTEMPTS) {
      console.error('Max retry attempts reached, giving up');
      return false;
    }

    // Only retry transient errors
    const code = error.code;
    const transientCodes = [
      'unavailable',
      'aborted',
      'deadline-exceeded',
      'resource-exhausted',
    ];

    if (transientCodes.includes(code.toString().toLowerCase())) {
      console.log('Transient error, will retry');
      return true; // Retry
    }

    // Don't retry permanent errors (permission-denied, invalid-argument, etc.)
    console.error('Permanent error, not retrying');
    return false;
  });

  const collections = [
    'investments',
    'cashflows',
    'goals',
    'archivedInvestments',
    'archivedCashflows',
    'archivedGoals',
    'documents',
    'fireSettings',
    'profile',
    'exchangeRates',
    'healthScores', // Week 2: Portfolio Health Score snapshots
  ];

  const PAGE_SIZE = 500;

  for (const collection of collections) {
    let hasMore = true;
    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

    while (hasMore) {
      let query = firestore
        .collection(`users/${userId}/${collection}`)
        .limit(PAGE_SIZE);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();

      if (snapshot.empty) {
        hasMore = false;
        break;
      }

      for (const doc of snapshot.docs) {
        bulkWriter.delete(doc.ref);
      }

      // If we got fewer docs than PAGE_SIZE, we're done
      if (snapshot.docs.length < PAGE_SIZE) {
        hasMore = false;
      } else {
        lastDoc = snapshot.docs[snapshot.docs.length - 1];
      }
    }
  }

  await bulkWriter.close();
}
