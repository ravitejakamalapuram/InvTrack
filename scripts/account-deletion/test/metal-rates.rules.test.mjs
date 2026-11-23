// Firestore rules for today's metal rates: a signed-in user (or guest) can read the one document; nobody on a
// client can list the collection or write. Run: `npm run test:emulator`.
import { after, before, beforeEach, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc } from 'firebase/firestore';

const rulesPath = fileURLToPath(new URL('../../../firestore.rules', import.meta.url));
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-invtrack-metal-rates',
    firestore: { rules: readFileSync(rulesPath, 'utf8') },
  });
});
after(async () => {
  await env?.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'metalRates/latest'), { usd: { gold: 116.1, silver: 1.35 } });
  });
});

const user = () => env.authenticatedContext('alice').firestore();
const guest = () => env.authenticatedContext('g1', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('metalRates', () => {
  it('a signed-in user and a guest can read the rates', async () => {
    await assertSucceeds(getDoc(doc(user(), 'metalRates/latest')));
    await assertSucceeds(getDoc(doc(guest(), 'metalRates/latest')));
  });

  it('a user who is not signed in reads nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'metalRates/latest')));
  });

  it('the collection cannot be listed', async () => {
    await assertFails(getDocs(collection(user(), 'metalRates')));
  });

  it('no client can create, change or delete the rates', async () => {
    const db = user();
    await assertFails(setDoc(doc(db, 'metalRates/other'), { usd: { gold: 1 } }));
    await assertFails(updateDoc(doc(db, 'metalRates/latest'), { usd: { gold: 999 } }));
    await assertFails(deleteDoc(doc(db, 'metalRates/latest')));
  });
});
