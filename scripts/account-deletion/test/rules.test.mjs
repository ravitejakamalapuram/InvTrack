// Firestore security-rules tests for the account-deletion queue.
// Runs against the Firestore emulator: `npm run test:emulator` (firebase emulators:exec).
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
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const rulesPath = fileURLToPath(new URL('../../../firestore.rules', import.meta.url));

let env;

const validRequest = () => ({ requestedAt: serverTimestamp(), source: 'web', version: 1 });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-invtrack',
    firestore: { rules: readFileSync(rulesPath, 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const asAlice = () => env.authenticatedContext('alice').firestore();
const asBob = () => env.authenticatedContext('bob').firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('deletionRequests/{uid}', () => {
  it('owner can create own request (web and app sources)', async () => {
    await assertSucceeds(setDoc(doc(asAlice(), 'deletionRequests/alice'), validRequest()));
    await assertSucceeds(
      setDoc(doc(asBob(), 'deletionRequests/bob'), { ...validRequest(), source: 'app' }),
    );
  });

  it('owner can get and delete own request', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'deletionRequests/alice'), {
        requestedAt: Timestamp.now(),
        source: 'web',
        version: 1,
      }),
    );
    await assertSucceeds(getDoc(doc(asAlice(), 'deletionRequests/alice')));
    await assertSucceeds(deleteDoc(doc(asAlice(), 'deletionRequests/alice')));
  });

  it('owner can get a request that does not exist (page probes before creating)', async () => {
    await assertSucceeds(getDoc(doc(asAlice(), 'deletionRequests/alice')));
  });

  it('cannot create for another uid', async () => {
    await assertFails(setDoc(doc(asBob(), 'deletionRequests/alice'), validRequest()));
  });

  it('signed-out clients cannot create, get or delete', async () => {
    await assertFails(setDoc(doc(anon(), 'deletionRequests/alice'), validRequest()));
    await assertFails(getDoc(doc(anon(), 'deletionRequests/alice')));
    await assertFails(deleteDoc(doc(anon(), 'deletionRequests/alice')));
  });

  it("another user cannot get or delete someone else's request", async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'deletionRequests/alice'), {
        requestedAt: Timestamp.now(),
        source: 'web',
        version: 1,
      }),
    );
    await assertFails(getDoc(doc(asBob(), 'deletionRequests/alice')));
    await assertFails(deleteDoc(doc(asBob(), 'deletionRequests/alice')));
  });

  it('rejects extra fields', async () => {
    await assertFails(
      setDoc(doc(asAlice(), 'deletionRequests/alice'), { ...validRequest(), email: 'a@b.c' }),
    );
  });

  it('rejects missing fields', async () => {
    await assertFails(
      setDoc(doc(asAlice(), 'deletionRequests/alice'), {
        requestedAt: serverTimestamp(),
        source: 'web',
      }),
    );
  });

  it('rejects a client-supplied timestamp (backdating)', async () => {
    const past = Timestamp.fromMillis(Date.now() - 3 * 24 * 3600 * 1000);
    await assertFails(
      setDoc(doc(asAlice(), 'deletionRequests/alice'), { ...validRequest(), requestedAt: past }),
    );
  });

  it('rejects unknown source and wrong version', async () => {
    await assertFails(
      setDoc(doc(asAlice(), 'deletionRequests/alice'), { ...validRequest(), source: 'email' }),
    );
    await assertFails(
      setDoc(doc(asAlice(), 'deletionRequests/alice'), { ...validRequest(), version: 2 }),
    );
  });

  it('cannot update an existing request (no re-dating)', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'deletionRequests/alice'), {
        requestedAt: Timestamp.now(),
        source: 'web',
        version: 1,
      }),
    );
    await assertFails(
      updateDoc(doc(asAlice(), 'deletionRequests/alice'), { requestedAt: serverTimestamp() }),
    );
    // setDoc over an existing doc is an update too.
    await assertFails(setDoc(doc(asAlice(), 'deletionRequests/alice'), validRequest()));
  });

  it('cannot list the queue', async () => {
    await assertFails(getDocs(collection(asAlice(), 'deletionRequests')));
  });
});

describe('deletionAudit and deletionRuns are closed to clients', () => {
  for (const name of ['deletionAudit', 'deletionRuns']) {
    it(`${name}: no read, list or write, even for a signed-in owner-looking id`, async () => {
      const db = asAlice();
      await assertFails(getDoc(doc(db, `${name}/alice`)));
      await assertFails(getDocs(collection(db, name)));
      await assertFails(setDoc(doc(db, `${name}/alice`), { x: 1 }));
      await assertFails(deleteDoc(doc(db, `${name}/alice`)));
    });
  }
});

describe('users/** stays owner-only', () => {
  it('owner can read and write own data at any depth', async () => {
    const db = asAlice();
    await assertSucceeds(setDoc(doc(db, 'users/alice/investments/i1'), { name: 'x' }));
    await assertSucceeds(setDoc(doc(db, 'users/alice/investments/i1/notes/n1'), { t: 1 }));
    await assertSucceeds(getDoc(doc(db, 'users/alice/investments/i1')));
    await assertSucceeds(getDocs(collection(db, 'users/alice/investments')));
  });

  it("other users and signed-out clients cannot touch someone else's data", async () => {
    await assertFails(setDoc(doc(asBob(), 'users/alice/investments/i1'), { name: 'x' }));
    await assertFails(getDoc(doc(asBob(), 'users/alice/investments/i1')));
    await assertFails(getDoc(doc(anon(), 'users/alice/investments/i1')));
  });

  it('the users/{uid} document itself is owner-only (US dollar fix answer)', async () => {
    const answer = { usdTagRepairResolvedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(asAlice(), 'users/alice'), answer, { merge: true }));
    await assertSucceeds(getDoc(doc(asAlice(), 'users/alice')));
    await assertFails(setDoc(doc(asBob(), 'users/alice'), answer, { merge: true }));
    await assertFails(getDoc(doc(asBob(), 'users/alice')));
    await assertFails(getDoc(doc(anon(), 'users/alice')));
  });
});

describe('everything else is denied', () => {
  it('unlisted top-level collection', async () => {
    await assertFails(setDoc(doc(asAlice(), 'other/alice'), { x: 1 }));
  });
});
