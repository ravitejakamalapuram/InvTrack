import { beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { runJob, requestByEmail, hashUid } from '../run.mjs';
import { verifyRun } from '../verify-run.mjs';
import { verifyUserGone } from '../verify.mjs';
import { deleteUserData } from '../delete.mjs';
import { createGa4Deletion } from '../ga4.mjs';
import { auth, authExists, db, DAY, exists, quiet, resetEmulators, seedRequest, seedUser, snapshot } from './helpers.mjs';

const opts = (over = {}) => ({ db, auth, runId: 'run1', dryRun: false, log: quiet, ...over });
// A made-up uid that is easy to search for in anything the job prints or writes.
const LEAK_UID = 'leakcanary7Zq2';

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
    assert.equal(audit.get('docsDeleted'), 4);
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
    assert.equal(out.results[0].docsToDelete, 4);
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

describe('Google Analytics user deletion (A102)', () => {
  const PROPERTY = '123456789';
  /** A GA client that records every uid it is asked about. */
  const spy = (impl = async () => ({ outcome: 'requested', status: 200 })) => {
    const uids = [];
    return {
      uids,
      ga4: async (uid) => {
        uids.push(uid);
        return impl(uid);
      },
    };
  };
  const auditOf = async (uid, runId = 'run1') => (await db.doc(`deletionAudit/${runId}-${hashUid(uid)}`).get()).data();

  it('live run asks once per processed uid and records the outcome without the uid', async () => {
    await seedUser('u1');
    await seedUser('u2');
    await seedRequest('u1', 2 * DAY);
    await seedRequest('u2', 2 * DAY);
    const { uids, ga4 } = spy();
    const out = await runJob(opts({ ga4 }));
    assert.equal(out.exitCode, 0);
    assert.deepEqual([...uids].sort(), ['u1', 'u2']);
    const audit = await auditOf('u1');
    assert.equal(audit.ga4, 'requested');
    assert.equal(audit.ga4Status, 200);
    assert.ok(!JSON.stringify(audit).includes('"u1"'));
    assert.equal(await authExists('u1'), false);
  });

  it('sends the USER_ID request through the real client with the configured property', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const calls = [];
    const request = async (o) => {
      calls.push(o.data);
      return { status: 200 };
    };
    await runJob(opts({ ga4: createGa4Deletion({ propertyId: PROPERTY, request }) }));
    assert.deepEqual(calls, [
      { kind: 'analytics#userDeletionRequest', id: { type: 'USER_ID', userId: 'u1' }, propertyId: PROPERTY },
    ]);
  });

  it('dry run makes zero calls and writes nothing', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const { uids, ga4 } = spy();
    await runJob(opts({ dryRun: true, ga4 }));
    assert.deepEqual(uids, []);
    assert.equal((await db.collection('deletionAudit').get()).size, 0);
  });

  it('a failed request never blocks the deletion, is recorded as failed and keeps the request for a retry', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const lines = [];
    const { ga4 } = spy(async () => ({ outcome: 'failed', status: 403 }));
    const out = await runJob(opts({ ga4, log: (l) => lines.push(l) }));
    assert.equal(out.exitCode, 0, 'the run still succeeds');
    assert.equal(out.ga4Failed, 1);
    assert.equal(await authExists('u1'), false);
    assert.deepEqual(await snapshot('users/u1'), {});
    // The request is the only memory of the uid, so it stays until Analytics has been asked.
    assert.equal(await exists('deletionRequests/u1'), true);
    const audit = await auditOf('u1');
    assert.equal(audit.verified, true);
    assert.equal(audit.ga4, 'failed');
    assert.equal(audit.ga4Status, 403);
    assert.ok(lines.some((l) => /Analytics/.test(l) && /failed/.test(l)));
    assert.ok(lines.every((l) => !l.includes('u1')), 'no log line names the uid');
  });

  it('a client that throws still cannot block the deletion', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const lines = [];
    const { ga4 } = spy(async () => {
      throw new Error('boom for u1');
    });
    const out = await runJob(opts({ ga4, log: (l) => lines.push(l) }));
    assert.equal(out.exitCode, 0);
    assert.equal(await authExists('u1'), false);
    assert.equal((await auditOf('u1')).ga4, 'failed');
    assert.equal(await exists('deletionRequests/u1'), true, 'kept for a retry');
    assert.ok(lines.every((l) => !l.includes('u1')));
  });

  it('the next run asks again, then removes the request once Analytics has been asked', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const first = spy(async () => ({ outcome: 'failed', status: 429 }));
    await runJob(opts({ ga4: first.ga4 }));
    assert.equal(await exists('deletionRequests/u1'), true);

    const second = spy();
    const out = await runJob(opts({ runId: 'run2', ga4: second.ga4 }));
    assert.equal(out.exitCode, 0);
    assert.deepEqual(second.uids, ['u1'], 'asked again');
    assert.equal(await exists('deletionRequests/u1'), false, 'removed after a successful request');
    assert.equal((await auditOf('u1', 'run2')).ga4, 'requested');
    assert.equal(await authExists('u1'), false, 'the account data stays deleted');
  });

  it('a request that keeps failing is not dropped and fails the run once it is over 3 days old', async () => {
    await seedUser('u1');
    await seedRequest('u1', 4 * DAY);
    const { ga4 } = spy(async () => ({ outcome: 'failed', status: 403 }));
    const out = await runJob(opts({ ga4, log: quiet }));
    assert.equal(out.stale, 1);
    assert.equal(out.exitCode, 1);
    assert.equal(await exists('deletionRequests/u1'), true);
  });

  it('a live run without a property warns once with a count, never with a uid, and still removes the request', async () => {
    await seedUser('u1');
    await seedUser('u2');
    await seedRequest('u1', 2 * DAY);
    await seedRequest('u2', 2 * DAY);
    const lines = [];
    const out = await runJob(opts({ ga4: createGa4Deletion({}), log: (l) => lines.push(l) }));
    assert.equal(out.exitCode, 0);
    assert.equal(out.ga4NotConfigured, 2);
    const warnings = lines.filter((l) => /not configured/i.test(l));
    assert.equal(warnings.length, 1);
    assert.match(warnings[0], /GA4_PROPERTY_ID/);
    assert.match(warnings[0], /2 account/);
    assert.ok(lines.every((l) => !l.includes('u1') && !l.includes('u2')));
    assert.equal(await exists('deletionRequests/u1'), false);
  });

  it('a dry run does not warn about a missing property', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const lines = [];
    const out = await runJob(opts({ dryRun: true, ga4: createGa4Deletion({}), log: (l) => lines.push(l) }));
    assert.equal(out.ga4NotConfigured, 0);
    assert.ok(lines.every((l) => !/not configured/i.test(l)));
  });

  it('with no property configured it records not-configured and makes no call', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const calls = [];
    const request = async (o) => calls.push(o);
    const out = await runJob(opts({ ga4: createGa4Deletion({ propertyId: undefined, request }) }));
    assert.equal(out.exitCode, 0);
    assert.equal(calls.length, 0);
    assert.equal((await auditOf('u1')).ga4, 'not-configured');
  });

  it('without a client option the audit says not-configured', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    await runJob(opts());
    assert.equal((await auditOf('u1')).ga4, 'not-configured');
  });

  it('is not called when the deleter itself fails', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const { uids, ga4 } = spy();
    const failing = async () => {
      throw new Error('boom');
    };
    const out = await runJob(opts({ ga4, deleter: failing }));
    assert.equal(out.exitCode, 1);
    assert.deepEqual(uids, []);
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
  // The verify job is given the run id and nothing else: no uid ever leaves the run job, because a step's env is
  // printed in a public log. It finds the run's accounts through the hashed deletionAudit records.
  it('passes after a clean run', async () => {
    await seedUser('u1');
    await seedUser('u2'); // not part of the run: must never be flagged
    await seedRequest('u1', 2 * DAY);
    await runJob(opts());
    const v = await verifyRun({ db, auth, runId: 'run1' });
    assert.deepEqual(v.problems, []);
    assert.equal(v.ok, true);
  });

  it('reads audit records that carry both the run id and an Analytics outcome, whatever the outcome', async () => {
    const outcomes = {
      u1: { outcome: 'requested', status: 200 },
      u2: { outcome: 'failed', status: 403 },
      u3: { outcome: 'not-configured', status: null },
    };
    const ga4 = async (uid) => outcomes[uid];
    for (const uid of ['u1', 'u2', 'u3']) {
      await seedUser(uid);
      await seedRequest(uid, 1.5 * DAY); // past the 24 h window, inside cooling + 1 day
    }
    const out = await runJob(opts({ ga4 }));
    assert.equal(out.exitCode, 0);
    for (const [uid, ga4Outcome] of [['u1', 'requested'], ['u2', 'failed'], ['u3', 'not-configured']]) {
      const audit = await db.doc(`deletionAudit/run1-${hashUid(uid)}`).get();
      assert.equal(audit.get('runId'), 'run1');
      assert.equal(audit.get('ga4'), ga4Outcome);
    }
    assert.equal(await exists('deletionRequests/u2'), true, 'a failed Analytics request keeps the request for a retry');
    const clean = await verifyRun({ db, auth, runId: 'run1' });
    assert.deepEqual(clean.problems, []);
    // The account whose Analytics request failed is still found by its hash.
    await seedUser('u2');
    const back = await verifyRun({ db, auth, runId: 'run1' });
    assert.ok(back.problems.some((p) => p.includes(hashUid('u2')) && /auth user still exists/.test(p)), back.problems.join('\n'));
    assert.ok(!back.problems.some((p) => p.includes(hashUid('u1')) || p.includes(hashUid('u3'))), back.problems.join('\n'));
  });

  it('finds an account that came back, by hash, without being given any uid', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    await runJob(opts());
    await seedUser('u1'); // resurrect it after the run reported success
    const v = await verifyRun({ db, auth, runId: 'run1' });
    assert.equal(v.ok, false);
    assert.ok(v.problems.some((p) => p.includes(hashUid('u1')) && /auth user still exists/.test(p)), v.problems.join('\n'));
    assert.ok(v.problems.some((p) => p.includes(hashUid('u1')) && /users data still exists/.test(p)), v.problems.join('\n'));
    assert.ok(!v.problems.join('\n').includes('u1@example.com'));
    assert.ok(!v.problems.join('\n').replaceAll(hashUid('u1'), '').includes('u1'), 'problem text must hold the hash, never the uid');
  });

  it('finds data that came back after the Auth user stayed gone', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    await runJob(opts());
    await db.doc('users/u1/investments/i9').set({ x: 1 }); // a stale client wrote again
    const v = await verifyRun({ db, auth, runId: 'run1' });
    assert.ok(v.problems.some((p) => p.includes(hashUid('u1')) && /users data still exists/.test(p)), v.problems.join('\n'));
  });

  it('still re-checks the accounts of a run that has no run record (it failed part-way)', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    await runJob(opts());
    await db.doc('deletionRuns/run1').delete();
    await seedUser('u1');
    const v = await verifyRun({ db, auth, runId: 'run1' });
    assert.ok(v.problems.some((p) => /missing/.test(p)));
    assert.ok(v.problems.some((p) => /auth user still exists/.test(p)));
  });

  it('does not flag accounts of another run', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    await runJob(opts({ runId: 'run0' }));
    await seedUser('u1');
    await db.doc('deletionRuns/run1').set({ refused: false });
    const v = await verifyRun({ db, auth, runId: 'run1' });
    assert.ok(!v.problems.some((p) => /still exists/.test(p)), v.problems.join('\n'));
  });

  it('fails when an orphan exists or the run record is missing', async () => {
    await db.doc('users/orphan/investments/i1').set({ x: 1 });
    const v = await verifyRun({ db, auth, runId: 'missing-run' });
    assert.ok(v.problems.some((p) => /orphaned/.test(p)));
    assert.ok(v.problems.some((p) => /missing/.test(p)));
  });

  it('fails on a request older than cooling + 1 day', async () => {
    await db.doc('deletionRuns/run1').set({ refused: false });
    await seedRequest('old', 3 * DAY);
    const v = await verifyRun({ db, auth, runId: 'run1' });
    assert.ok(v.problems.some((p) => /older than cooling/.test(p)));
  });
});

describe('run.mjs as the workflow starts it', () => {
  // Spawned for real, the way the workflow does it, so the GITHUB_OUTPUT it leaves behind is what the verify job sees.
  const start = (extra = {}, nodeArgs = []) => {
    const dir = mkdtempSync(join(tmpdir(), 'run-mjs-'));
    const outFile = join(dir, 'output');
    const summaryFile = join(dir, 'summary');
    writeFileSync(outFile, '');
    writeFileSync(summaryFile, '');
    const r = spawnSync(process.execPath, [...nodeArgs, new URL('../run.mjs', import.meta.url).pathname], {
      env: { ...process.env, DRY_RUN: 'false', GITHUB_RUN_ID: '777', GITHUB_RUN_ATTEMPT: '2', GCLOUD_PROJECT: 'demo-invtrack', GITHUB_OUTPUT: outFile, GITHUB_STEP_SUMMARY: summaryFile, ...extra },
      encoding: 'utf8',
      timeout: 60_000,
    });
    const output = readFileSync(outFile, 'utf8');
    const summary = readFileSync(summaryFile, 'utf8');
    rmSync(dir, { recursive: true, force: true });
    return { status: r.status, output, summary, log: `${r.stdout}${r.stderr}` };
  };

  it('hands the next job the run id and no uid', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    const r = start();
    assert.equal(r.status, 0, r.log);
    assert.equal(r.output, 'run_id=777-2\n');
    assert.equal(await authExists('u1'), false);
    assert.equal((await db.doc(`deletionAudit/777-2-${hashUid('u1')}`).get()).exists, true);
  });

  it('announces the run id before it touches anything, so verify still runs when the job crashes', async () => {
    await seedUser('u1');
    await seedRequest('u1', 2 * DAY);
    // The Auth emulator is unreachable, so the run dies on its first Auth call.
    const r = start({ FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:1' });
    assert.notEqual(r.status, 0, 'the run is meant to crash here');
    assert.equal(r.output, 'run_id=777-2\n');
  });

  // The step summary and the log of this job are public. A library error can be codeless and carry the uid in its
  // message, so only a short code may be recorded (see safe-error.mjs). fault-auth.mjs makes one Auth call throw such an error.
  const faulty = (method) =>
    start({ FAULT_AUTH_METHOD: method }, ['--import', new URL('./fault-auth.mjs', import.meta.url).href]);
  const assertNoUid = (r, uid) => {
    assert.ok(!r.summary.includes(uid), `the uid reached the step summary:\n${r.summary}`);
    assert.ok(!r.log.includes(uid), `the uid reached stdout or stderr:\n${r.log}`);
  };

  it('keeps the uid out of the summary, stdout and stderr when deleteUser throws a codeless error', async () => {
    await seedUser(LEAK_UID);
    await seedRequest(LEAK_UID, 2 * DAY);
    const r = faulty('deleteUser');
    assert.equal(r.status, 1, r.log);
    assertNoUid(r, LEAK_UID);
    assert.ok(r.summary.includes(`| ${hashUid(LEAK_UID)} | request | - | - | - | error |`), r.summary);
  });

  it('keeps the uid out of the summary, stdout and stderr when the Auth lookup in the verifier throws a codeless error', async () => {
    await seedUser(LEAK_UID);
    await seedRequest(LEAK_UID, 2 * DAY);
    const r = faulty('getUser');
    assert.equal(r.status, 1, r.log);
    assertNoUid(r, LEAK_UID);
    assert.ok(r.summary.includes('auth lookup failed: error'), r.summary);
  });
});

describe('error text recorded for a failed account', () => {
  it('records only a safe code, never the message of an error that holds the uid', async () => {
    await seedRequest(LEAK_UID, 2 * DAY);
    const deleter = async ({ uid }) => {
      throw new Error(`could not delete ${uid}`);
    };
    const out = await runJob(opts({ deleter }));
    assert.equal(out.results[0].error, 'error');
    assert.ok(!JSON.stringify(out).includes(LEAK_UID));
  });

  it('keeps a short error code', async () => {
    await seedRequest(LEAK_UID, 2 * DAY);
    const deleter = async () => {
      throw Object.assign(new Error('x'), { code: 'auth/internal-error' });
    };
    const out = await runJob(opts({ deleter }));
    assert.equal(out.results[0].error, 'auth/internal-error');
  });

  it('the verifier reports a failed Auth lookup by code only', async () => {
    const lookup = (e) => verifyUserGone({ db, auth: { getUser: async () => { throw e; } }, uid: LEAK_UID });
    assert.deepEqual((await lookup(new Error(`lookup of ${LEAK_UID} failed`))).problems, ['auth lookup failed: error']);
    assert.deepEqual((await lookup(Object.assign(new Error('x'), { code: 'auth/internal-error' }))).problems, ['auth lookup failed: auth/internal-error']);
  });
});
