// Shared setup for the job tests: Admin SDK against the emulators started by `firebase emulators:exec`.
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

export const PROJECT = 'demo-invtrack';
export const DAY = 24 * 60 * 60 * 1000;

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Run via `npm run test:emulator` (needs the Firestore and Auth emulators).');
}
if (getApps().length === 0) initializeApp({ projectId: PROJECT });

export const db = getFirestore();
export const auth = getAuth();
export const quiet = () => {};

export async function resetEmulators() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
  await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/accounts`, { method: 'DELETE' });
}

/** An Auth user plus data deeper than the app ever writes (proves recursiveDelete catches unknown data). */
export async function seedUser(uid, { guest = false } = {}) {
  await auth.createUser(guest ? { uid } : { uid, email: `${uid}@example.com`, password: 'secret-pass-1' });
  await db.doc(`users/${uid}/investments/i1`).set({ name: 'x' });
  await db.doc(`users/${uid}/investments/i1/notes/n1`).set({ text: 'nested' });
  await db.doc(`users/${uid}/fireSettings/settings`).set({ a: 1 });
  await db.doc(`users/${uid}/valuations/v1`).set({ investmentId: 'i1', amount: 1, currency: 'INR' });
}

export const seedRequest = (uid, ageMs, now = new Date()) =>
  db.doc(`deletionRequests/${uid}`).set({
    requestedAt: Timestamp.fromDate(new Date(now.getTime() - ageMs)),
    source: 'web',
    version: 1,
  });

export const exists = async (path) => (await db.doc(path).get()).exists;
export const authExists = (uid) => auth.getUser(uid).then(() => true, () => false);
export const snapshot = async (path) => {
  const out = {};
  const walk = async (ref) => {
    for (const col of await ref.listCollections()) {
      for (const d of await col.listDocuments()) {
        const s = await d.get();
        if (s.exists) out[d.path] = s.data();
        await walk(d);
      }
    }
  };
  await walk(db.doc(path));
  return out;
};
