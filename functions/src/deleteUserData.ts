import { getFirestore, Firestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as functionsV1 from 'firebase-functions/v1';

/**
 * Deletes EVERYTHING stored under `users/{uid}`: the user document and every
 * subcollection at any depth, including collections the app does not know
 * about yet (the client SDK cannot list subcollections, so it cannot do this).
 *
 * Idempotent: running it again after a partial failure deletes whatever is
 * left, so "retry" is "resume". Resolves only once nothing is left under the
 * user document; throws otherwise.
 */
export async function deleteAllUserData(
  db: Firestore,
  uid: string,
): Promise<void> {
  if (!uid) {
    throw new Error('deleteAllUserData: uid is required');
  }
  const userDoc = db.collection('users').doc(uid);

  await db.recursiveDelete(userDoc);

  const leftover = await userDoc.listCollections();
  if (leftover.length > 0) {
    throw new Error(
      `deleteAllUserData: ${leftover.length} subcollection(s) still present ` +
        `for users/${uid}: ${leftover.map((c) => c.id).join(', ')}`,
    );
  }
}

/**
 * Core of the `deleteUserData` callable, kept free of the Functions runtime so
 * it can be unit-tested. The uid ALWAYS comes from the verified auth token,
 * never from request data, so a caller can only delete their own data.
 */
export async function handleDeleteUserData(
  authUid: string | undefined,
  deleteFn: (uid: string) => Promise<void>,
): Promise<{ deleted: true }> {
  if (!authUid) {
    throw new HttpsError('unauthenticated', 'Sign in to delete your data.');
  }
  try {
    await deleteFn(authUid);
  } catch (error) {
    logger.error('Account data deletion failed', {
      uid: authUid,
      error: error instanceof Error ? error.message : String(error),
    });
    throw new HttpsError(
      'internal',
      'Account data deletion did not complete. It is safe to retry.',
    );
  }
  logger.info('Account data deletion complete', { uid: authUid });
  return { deleted: true };
}

/**
 * Callable used by the app's "Delete account" flow. Runs to completion on the
 * server even if the phone disconnects mid-call; the app only deletes the
 * Auth account after this returns `{deleted: true}`.
 */
export const deleteUserData = onCall(
  { timeoutSeconds: 540, memory: '512MiB' },
  (request) =>
    handleDeleteUserData(request.auth?.uid, (uid) =>
      deleteAllUserData(getFirestore(), uid),
    ),
);

/**
 * Backstop: whenever an Auth user is deleted by any path (console, the
 * anonymous-user cleanup, or an app crash between "delete data" and "delete
 * account"), remove whatever is still stored for them. After the Auth account
 * is gone the security rules block every client, so only the server can.
 */
export const onAuthUserDeleted = functionsV1.auth
  .user()
  .onDelete((user) => deleteAllUserData(getFirestore(), user.uid));
