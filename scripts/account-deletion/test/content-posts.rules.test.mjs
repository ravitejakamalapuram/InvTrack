// Firestore rules for the shared content list (posts for the Telegram channel and the app's tip card).
// Anyone signed in (a guest counts) may read approved posts. Nobody on a client may write, and the
// per-channel delivery records are for the job only. Run: `npm run test:emulator`.
import { after, before, beforeEach, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const rulesPath = fileURLToPath(new URL('../../../firestore.rules', import.meta.url));

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-invtrack-content',
    firestore: { rules: readFileSync(rulesPath, 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'contentPosts/ok'), { title: 'T', body: 'B', status: 'approved' });
    await setDoc(doc(db, 'contentPosts/draft'), { title: 'T', body: 'B', status: 'draft' });
    await setDoc(doc(db, 'contentPosts/ok/deliveries/telegram'), { status: 'posted' });
  });
});

const user = () => env.authenticatedContext('alice').firestore();
const guest = () => env.authenticatedContext('guest1', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('contentPosts', () => {
  it('a signed-in user and a guest can read an approved post', async () => {
    await assertSucceeds(getDoc(doc(user(), 'contentPosts/ok')));
    await assertSucceeds(getDoc(doc(guest(), 'contentPosts/ok')));
  });

  it('a signed-in user can list approved posts with a status filter', async () => {
    const snap = await assertSucceeds(
      getDocs(query(collection(user(), 'contentPosts'), where('status', '==', 'approved'))),
    );
    assert_equal(snap.size, 1);
  });

  it('a draft cannot be read, and an unfiltered list is refused', async () => {
    await assertFails(getDoc(doc(user(), 'contentPosts/draft')));
    await assertFails(getDocs(collection(user(), 'contentPosts')));
  });

  it('a user who is not signed in reads nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'contentPosts/ok')));
  });

  it('no client can create, change or delete a post', async () => {
    const db = user();
    await assertFails(setDoc(doc(db, 'contentPosts/new'), { title: 'x', body: 'y', status: 'approved' }));
    await assertFails(updateDoc(doc(db, 'contentPosts/ok'), { title: 'changed' }));
    await assertFails(deleteDoc(doc(db, 'contentPosts/ok')));
  });
});

describe('contentPosts/{id}/deliveries', () => {
  it('clients cannot read or write delivery records', async () => {
    const db = user();
    await assertFails(getDoc(doc(db, 'contentPosts/ok/deliveries/telegram')));
    await assertFails(setDoc(doc(db, 'contentPosts/ok/deliveries/telegram'), { status: 'posted' }));
  });
});

function assert_equal(actual, expected) {
  if (actual !== expected) throw new Error(`expected ${expected}, got ${actual}`);
}
