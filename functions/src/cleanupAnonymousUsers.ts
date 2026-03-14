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
 */
async function deleteUserData(userId: string): Promise<void> {
  const firestore = admin.firestore();
  const batch = firestore.batch();

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
  ];

  for (const collection of collections) {
    const snapshot = await firestore
      .collection(`users/${userId}/${collection}`)
      .get();

    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  }

  await batch.commit();
}

