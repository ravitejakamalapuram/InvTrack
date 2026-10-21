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

// A32 (#774): allow-list of the subcollections the app writes, plus type and length checks.
// Each "real write" below mirrors the map built by the matching Dart repository.
describe('users/{uid} write validation', () => {
  const ts = () => Timestamp.now();
  const realWrites = {
    investments: {
      name: 'FD', type: 'fixedDeposit', status: 'OPEN', notes: 'n', createdAt: ts(),
      closedAt: null, updatedAt: serverTimestamp(), maturityDate: ts(), incomeFrequency: null,
      isArchived: false, startDate: ts(), expectedRate: 7.1, tenureMonths: 12, platform: 'Bank',
      interestPayoutMode: null, autoRenewal: false, riskLevel: null, compoundingFrequency: null,
      currency: 'INR', currentValue: 1000.5, currentValueDate: ts(), customTypeId: null,
      customTypeLabel: null,
    },
    cashflows: {
      investmentId: 'i1', date: ts(), type: 'INVEST', amount: 100, notes: '', createdAt: ts(),
      currency: 'INR',
    },
    goals: {
      name: 'g', type: 'x', targetAmount: 1, targetMonthlyIncome: null, targetDate: null,
      trackingMode: 'all', linkedInvestmentIds: ['i1'], linkedTypes: ['stocks'], icon: 'i',
      colorValue: 4278190080, isArchived: false, currency: 'INR', createdAt: ts(),
      updatedAt: serverTimestamp(),
    },
    expectedCashFlows: {
      investmentId: 'i1', expectedDate: ts(), expectedAmount: 5, currency: 'INR',
      predictionSource: 'x', status: 'pending', matchedCashFlowId: null, actualAmount: null,
      actualDate: null, notes: null, createdAt: ts(), updatedAt: serverTimestamp(),
      platformDelayDays: 0, varianceFactor: 1.0,
    },
    documents: {
      investmentId: 'i1', name: 'd', fileName: 'd.pdf', type: 'other', mimeType: 'application/pdf',
      localPath: '/x', fileSize: 10, createdAt: ts(), updatedAt: serverTimestamp(),
    },
    valuations: {
      investmentId: 'i1', amount: 9.5, currency: 'INR', effectiveDate: ts(), kind: 'k',
      provenance: 'manual', createdAt: ts(), updatedAt: serverTimestamp(), deletedAt: null,
    },
    healthScores: {
      overallScore: 70.5, returnsScore: 1, diversificationScore: 2, liquidityScore: 3,
      goalAlignmentScore: 4, actionReadinessScore: 5, calculatedAt: ts(), metadata: { a: 1 },
    },
    fireSettings: {
      schemaVersion: 1, monthlyExpenses: 1, safeWithdrawalRate: 4, birthYear: 1990, currentAge: 30,
      targetFireAge: 50, lifeExpectancy: 90, inflationRate: 6, preRetirementReturn: 10,
      postRetirementReturn: 7, healthcareBuffer: 0, emergencyMonths: 6, fireType: 'regular',
      monthlyPassiveIncome: 0, expectedPension: 0, otherAssets: 0, monthlySip: 0, currency: 'INR',
      isSetupComplete: true, createdAt: ts(), updatedAt: serverTimestamp(),
    },
    profile: {
      schemaVersion: 1, userId: 'alice', preferredCurrency: 'INR', preferredLocale: 'en_IN',
      countryCode: 'IN', languageCode: 'en', dateFormatPattern: 'ddMMyyyy', isFirstLogin: false,
      createdAt: ts(), updatedAt: serverTimestamp(),
    },
    exchangeRates: {
      type: 'live', date: '2026-10-21', from: 'USD', to: 'INR', rate: 83.1, expiresAt: ts(),
      fetchedAt: serverTimestamp(),
    },
    customInvestmentTypes: { label: 'Chit fund', createdAt: ts(), updatedAt: ts(), removedAt: null },
  };

  for (const [name, data] of Object.entries(realWrites)) {
    it(`${name}: the app's real write is allowed (create, update, delete)`, async () => {
      const ref = doc(asAlice(), `users/alice/${name}/d1`);
      await assertSucceeds(setDoc(ref, data));
      await assertSucceeds(updateDoc(ref, { updatedAt: serverTimestamp() }));
      await assertSucceeds(deleteDoc(ref));
    });
  }

  it('archivedInvestments, archivedCashflows and archivedGoals take the same documents', async () => {
    const db = asAlice();
    await assertSucceeds(setDoc(doc(db, 'users/alice/archivedInvestments/a'), realWrites.investments));
    await assertSucceeds(setDoc(doc(db, 'users/alice/archivedCashflows/a'), realWrites.cashflows));
    await assertSucceeds(setDoc(doc(db, 'users/alice/archivedGoals/a'), realWrites.goals));
  });

  it('users/{uid}: the US dollar answer fields are allowed, other types are not', async () => {
    const ref = doc(asAlice(), 'users/alice');
    await assertSucceeds(
      setDoc(ref, { usdTagRepairResolvedAt: serverTimestamp(), usdTagRepairExtendedResolvedAt: serverTimestamp() }, { merge: true }),
    );
    await assertFails(setDoc(ref, { usdTagRepairResolvedAt: 'yes' }, { merge: true }));
    await assertSucceeds(deleteDoc(ref));
  });

  it('unknown subcollection write is denied', async () => {
    await assertFails(setDoc(doc(asAlice(), 'users/alice/secrets/s1'), { a: 1 }));
    await assertFails(getDoc(doc(asAlice(), 'users/alice/secrets/s1')));
  });

  it('a collection nested under a known document is denied', async () => {
    await assertFails(setDoc(doc(asAlice(), 'users/alice/investments/i1/notes/n1'), { t: 1 }));
  });

  it('a note over 2000 characters is denied, 2000 is allowed', async () => {
    const ref = doc(asAlice(), 'users/alice/cashflows/c1');
    await assertSucceeds(setDoc(ref, { ...realWrites.cashflows, notes: 'x'.repeat(2000) }));
    await assertFails(setDoc(ref, { ...realWrites.cashflows, notes: 'x'.repeat(2001) }));
    await assertFails(
      setDoc(doc(asAlice(), 'users/alice/investments/i1'), { ...realWrites.investments, notes: 'x'.repeat(2001) }),
    );
  });

  it('a wrong field type is denied', async () => {
    const db = asAlice();
    await assertFails(setDoc(doc(db, 'users/alice/cashflows/c1'), { ...realWrites.cashflows, amount: '100' }));
    await assertFails(setDoc(doc(db, 'users/alice/investments/i1'), { ...realWrites.investments, name: 42 }));
    await assertFails(setDoc(doc(db, 'users/alice/goals/g1'), { ...realWrites.goals, linkedTypes: 'stocks' }));
    await assertFails(setDoc(doc(db, 'users/alice/investments/i1'), { ...realWrites.investments, createdAt: 'today' }));
  });

  it('a partial update cannot leave an invalid merged document', async () => {
    const ref = doc(asAlice(), 'users/alice/cashflows/c1');
    await assertSucceeds(setDoc(ref, realWrites.cashflows));
    await assertFails(updateDoc(ref, { notes: 'x'.repeat(2001) }));
    await assertFails(updateDoc(ref, { amount: 'a lot' }));
  });

  it('another user still cannot write a valid document', async () => {
    await assertFails(setDoc(doc(asBob(), 'users/alice/cashflows/c1'), realWrites.cashflows));
  });
});
