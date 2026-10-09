import { beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { runJob, requestByEmail, hashUid, claimDeletionRequest } from '../run.mjs';
import { verifyRun } from '../verify-run.mjs';
import { deleteUserData } from '../delete.mjs';
import { auth, authExists, db, DAY, exists, quiet, resetEmulators, seedRequest, seedUser, snapshot } from './helpers.mjs';

const opts = (over = {}) => ({ db, auth, runId: 'run1', dryRun: false, log: quiet, ...over });

beforeEach(resetEmulators);

describe('deletion run', () => {
  it('deletes nested data and the Auth user, writes a hashed audit, removes the request last', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const out = await runJob(opts());
    assert.equal(out.exitCode, 0);
    assert.deepEqual(await snapshot('users/u1'), {});
    assert.equal(await authExists('u1'), false);
    assert.equal(await exists('deletionRequests/u1'), false);
    const audit = await db.doc(`deletionAudit/run1-${hashUid('u1')}`).get();
    assert.equal(audit.get('verified'), true);
    assert.equal(audit.get('outcome'), 'deleted');
    assert.equal(audit.get('docsDeleted'), 3);
    assert.equal(audit.get('authDeleted'), true);
    assert.ok(!JSON.stringify(audit.data()).includes('u1@example.com'));
    assert.ok(!JSON.stringify(audit.data()).includes('"u1"'));
    assert.equal((await db.doc('deletionRuns/run1').get()).get('refused'), false);
  });

  it('leaves other users byte-identical', async () => {
    await seedUser('u1');
    await seedUser('u2');
    await seedRequest('u1', 2 * DAY);
    const before = await snapshot('users/u2');
    await runJob(opts());
    assert.deepEqual(await snapshot('users/u2'), before);
    assert.equal(await authExists('u2'), true);
  });

  it('handles a request for a uid with no data and no Auth user', async () => {
    await seedRequest('ghost', 2 * DAY);
    const out = await runJob(opts());
    assert.equal(out.exitCode, 0);
    assert.equal(await exists('deletionRequests/ghost'), false);
    const audit = await db.doc(`deletionAudit/run1-${hashUid('ghost')}`).get();
    assert.equal(audit.get('outcome'), 'nothing-to-delete');
  });

  it('dry run deletes nothing and writes nothing', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const out = await runJob(opts({ dryRun: true }));
    assert.equal(out.exitCode, 0);
    assert.equal(out.results[0].docsToDelete, 3);
    assert.equal(await exists('users/u1/investments/i1'), true);
    assert.equal(await authExists('u1'), true);
    assert.equal(await exists('deletionRequests/u1'), true);
    assert.equal((await db.collection('deletionAudit').get()).size, 0);
    assert.equal((await db.collection('deletionRuns').get()).size, 0);
  });

  it('refuses over the cap with exit 2 and deletes nothing; force overrides', async () => {
    for (const u of ['a', 'b', 'c']) {
      await seedUser(u);
      await seedRequest(u, 2 * DAY);
    }
    const out = await runJob(opts({ maxPerRun: 2 }));
    assert.equal(out.exitCode, 2);
    assert.equal(out.refused, true);
    assert.equal(await exists('users/a/investments/i1'), true);
    assert.equal((await db.doc('deletionRuns/run1').get()).get('refused'), true);

    const forced = await runJob(opts({ maxPerRun: 2, force: true, runId: 'run2' }));
    assert.equal(forced.exitCode, 0);
    assert.equal(await exists('users/a/investments/i1'), false);
  });

  it('skips requests still inside the 24 h withdrawal window', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * 60 * 60 * 1000);
    const out = await runJob(opts());
    assert.equal(out.exitCode, 0);
    assert.equal(out.results.length, 0);
    assert.equal(await exists('users/u1/investments/i1'), true);
    assert.equal(await exists('deletionRequests/u1'), true);
  });

  it('does not delete an account when its request disappears after the queue snapshot', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    let deleteCalls = 0;
    const withdrawBeforeClaim = async ({ db: d, uid }) => {
      await d.doc(`deletionRequests/${uid}`).delete();
      return false;
    };
    const out = await runJob(opts({
      claimRequest: withdrawBeforeClaim,
      deleter: async (args) => { deleteCalls++; return deleteUserData(args); },
    }));
    assert.equal(out.exitCode, 0);
    assert.equal(out.results[0].skipped, 'request withdrawn or another run holds an active claim');
    assert.equal(deleteCalls, 0);
    assert.equal(await exists('users/u1/investments/i1'), true);
    assert.equal(await authExists('u1'), true);
  });

  it('atomically claims a due request once and rejects a second active claimant', async () => {
    await seedRequest('u1', 2 * DAY);
    const now = new Date();
    assert.equal(await claimDeletionRequest({ db, uid: 'u1', now, runId: 'run1' }), true);
    assert.equal(await claimDeletionRequest({ db, uid: 'u1', now, runId: 'run2' }), false);
    const request = await db.doc('deletionRequests/u1').get();
    assert.equal(request.get('status'), 'processing');
    assert.equal(request.get('processingRunId'), 'run1');
  });

  it('resumes after a crash between recursiveDelete and deleteUser', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const crashing = async ({ db: d, uid }) => {
      await d.recursiveDelete(d.collection('users').doc(uid));
      throw new Error('simulated crash');
    };
    const first = await runJob(opts({ deleter: crashing }));
    assert.equal(first.exitCode, 1);
    assert.equal(await exists('deletionRequests/u1'), true, 'request must survive a crash');
    assert.equal(await authExists('u1'), true);

    const second = await runJob(opts({ runId: 'run2' }));
    assert.equal(second.exitCode, 0);
    assert.equal(await authExists('u1'), false);
    assert.equal(await exists('deletionRequests/u1'), false);
  });

  it('raises the stale alert for a request older than 3 days that cannot be processed', async () => {
    await seedUser('u1');
    await seedRequest('u1', 4 * DAY);
    const failing = async () => {
      throw new Error('boom');
    };
    const out = await runJob(opts({ deleter: failing }));
    assert.equal(out.stale, 1);
    assert.equal(out.exitCode, 1);
  });

  it('finds orphaned data (missing-ancestor users/{uid}) with no Auth user', async () => {
    await db.doc('users/orphan/investments/i1').set({ x: 1 });
    await seedUser('keep');
    const out = await runJob(opts());
    assert.equal(out.exitCode, 0);
    assert.equal(out.results.length, 1);
    assert.equal(out.results[0].source, 'orphan');
    assert.equal(await exists('users/orphan/investments/i1'), false);
    assert.equal(await exists('users/keep/investments/i1'), true);
  });

  it('guest sweep is off by default and only removes inactive guests when on', async () => {
    await seedUser('guest1', { guest: true });
    await seedUser('signedin');
    const later = new Date(Date.now() + 31 * DAY);

    const off = await runJob(opts({ now: later }));
    assert.equal(off.results.length, 0);
    assert.equal(await authExists('guest1'), true);

    const early = await runJob(opts({ sweepGuestsDays: 30, runId: 'run2' }));
    assert.equal(early.results.length, 0, 'an active guest is kept');

    const on = await runJob(opts({ now: later, sweepGuestsDays: 30, runId: 'run3' }));
    assert.equal(on.results.length, 1);
    assert.equal(on.results[0].source, 'guest-inactive');
    assert.equal(await authExists('guest1'), false);
    assert.equal(await authExists('signedin'), true, 'a signed-in (linked) user is never swept');
  });

  it('request_email creates a normal queue entry and deletes nothing', async () => {
    await seedUser('u1');
    await requestByEmail({ db, auth, email: 'u1@example.com', dryRun: true, log: quiet });
    assert.equal(await exists('deletionRequests/u1'), false);
    await requestByEmail({ db, auth, email: 'u1@example.com', dryRun: false, log: quiet });
    const req = await db.doc('deletionRequests/u1').get();
    assert.equal(req.get('source'), 'app');
    assert.equal(req.get('version'), 1);
    assert.equal(await exists('users/u1/investments/i1'), true);
    assert.equal(await authExists('u1'), true);
  });
});

describe('verifier must fail when deletion is incomplete (mutation tests)', () => {
  it('flags a nested document the deleter left behind', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const leaky = async ({ db: d, auth: a, uid }) => {
      const keep = await d.doc(`users/${uid}/investments/i1/notes/n1`).get();
      const res = await deleteUserData({ db: d, auth: a, uid });
      await d.doc(`users/${uid}/investments/i1/notes/n1`).set(keep.data());
      return res;
    };
    const out = await runJob(opts({ deleter: leaky }));
    assert.equal(out.exitCode, 1, 'a leftover must fail the run');
    assert.equal(out.results[0].verified, false);
    assert.ok(out.results[0].problems.some((p) => /still exist/.test(p)));
    assert.equal(await exists('deletionRequests/u1'), true, 'request kept for retry');
    assert.equal((await db.doc(`deletionAudit/run1-${hashUid('u1')}`).get()).get('verified'), false);
  });

  it('flags an Auth user that still exists', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const noAuthDelete = (args) => deleteUserData({ ...args, auth: { deleteUser: async () => {} } });
    const out = await runJob(opts({ deleter: noAuthDelete }));
    assert.equal(out.exitCode, 1);
    assert.ok(out.results[0].problems.includes('auth user still exists'));
    assert.equal(await exists('deletionRequests/u1'), true);
  });
});

describe('independent verify job', () => {
  it('passes after a clean run', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const out = await runJob(opts());
    const v = await verifyRun({ db, auth, runId: 'run1', uids: out.processedUids });
    assert.deepEqual(v.problems, []);
    assert.equal(v.ok, true);
  });

  it('fails when data or the Auth user of a processed uid is back, an orphan exists, or the run record is missing', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const out = await runJob(opts());
    await seedUser('u1'); // resurrect it after the run reported success
    const v = await verifyRun({ db, auth, runId: 'run1', uids: out.processedUids });
    assert.equal(v.ok, false);
    assert.ok(v.problems.some((p) => /auth user still exists/.test(p)));

    await db.doc('users/orphan/investments/i1').set({ x: 1 });
    const v2 = await verifyRun({ db, auth, runId: 'missing-run', uids: [] });
    assert.ok(v2.problems.some((p) => /orphaned/.test(p)));
    assert.ok(v2.problems.some((p) => /missing/.test(p)));
  });

  it('fails on a request older than cooling + 1 day', async () => {
    await db.doc('deletionRuns/run1').set({ refused: false });
    await seedRequest('old', 3 * DAY);
    const v = await verifyRun({ db, auth, runId: 'run1', uids: [] });
    assert.ok(v.problems.some((p) => /older than cooling/.test(p)));
  });
});
