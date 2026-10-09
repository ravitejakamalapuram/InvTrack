// Account-deletion job. See README.md. Every phase is idempotent; the request document is
// deleted last so a crash leaves it for the next run.
import { createHash } from 'node:crypto';
import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { countDocs, deleteUserData } from './delete.mjs';
import { COOLING_MS, findInactiveGuests, findOrphans, loadRequests, STALE_MS } from './sweep.mjs';
import { verifyUserGone } from './verify.mjs';

export const hashUid = (uid) => createHash('sha256').update(uid).digest('hex').slice(0, 16);

// A processing claim closes the race between reading the queue and deleting the account.
// A crashed runner may be retried after the lease expires; ordinary failures release it sooner.
export const CLAIM_LEASE_MS = 2 * 60 * 60 * 1000;

export async function claimDeletionRequest({ db, uid, now, runId }) {
  const ref = db.collection('deletionRequests').doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false; // withdrawn after the queue snapshot was read
    const data = snap.data() ?? {};
    const requestedAt = data.requestedAt;
    if (
      typeof requestedAt?.toDate !== 'function' ||
      now.getTime() - requestedAt.toDate().getTime() < COOLING_MS
    ) return false;

    const status = data.status ?? 'pending'; // existing v1 requests have no status field
    if (status === 'processing') {
      const claimedAt = data.claimedAt;
      if (
        typeof claimedAt?.toDate === 'function' &&
        now.getTime() - claimedAt.toDate().getTime() < CLAIM_LEASE_MS
      ) return false; // another live run owns the lease
    } else if (status !== 'pending') {
      return false;
    }

    tx.update(ref, {
      status: 'processing',
      processingRunId: runId,
      claimedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}

export async function releaseDeletionRequestClaim({ db, uid, runId }) {
  const ref = db.collection('deletionRequests').doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get('status') !== 'processing' || snap.get('processingRunId') !== runId) {
      return false;
    }
    tx.update(ref, {
      status: 'pending',
      processingRunId: FieldValue.delete(),
      claimedAt: FieldValue.delete(),
    });
    return true;
  });
}

export async function runJob({
  db,
  auth,
  now = new Date(),
  runId,
  dryRun = true,
  force = false,
  maxPerRun = 25,
  sweepGuestsDays = 0,
  deleter = deleteUserData,
  verifier = verifyUserGone,
  claimRequest = claimDeletionRequest,
  releaseRequestClaim = releaseDeletionRequestClaim,
  log = console.log,
}) {
  const { due, fresh, malformed } = await loadRequests(db, now);
  const candidates = new Map();
  for (const r of due) candidates.set(r.uid, { source: 'request', requestedAt: r.requestedAt, hasRequest: true });
  for (const uid of await findOrphans(db, auth)) {
    if (!candidates.has(uid)) candidates.set(uid, { source: 'orphan', requestedAt: null, hasRequest: false });
  }
  if (sweepGuestsDays > 0) {
    for (const uid of await findInactiveGuests(auth, now, sweepGuestsDays)) {
      if (!candidates.has(uid)) candidates.set(uid, { source: 'guest-inactive', requestedAt: null, hasRequest: false });
    }
  }
  log(
    `Queue: ${due.length} due, ${fresh.length} still in the 24 h withdrawal window, ${malformed.length} malformed. ` +
      `Candidates: ${candidates.size} (dry_run=${dryRun}).`,
  );

  const refused = candidates.size > maxPerRun && !force;
  const results = [];
  const removedRequests = new Set();
  const skippedRequests = new Set();

  if (refused) {
    log(`REFUSED: ${candidates.size} candidates exceed max_per_run=${maxPerRun}; nothing deleted. Re-run with force to override.`);
  } else {
    for (const [uid, c] of candidates) {
      const uidHash = hashUid(uid);
      const result = { uidHash, source: c.source, ok: false };
      results.push(result);
      try {
        if (dryRun) {
          result.docsToDelete = await countDocs(db.collection('users').doc(uid));
          result.ok = true;
          continue;
        }
        if (c.hasRequest && !(await claimRequest({ db, uid, now, runId }))) {
          // A withdrawal or another active worker won the race after the initial queue read.
          // Never proceed with destructive work from a stale snapshot.
          result.ok = true;
          result.skipped = 'request withdrawn or another run holds an active claim';
          skippedRequests.add(uid);
          continue;
        }
        const { docsDeleted, authDeleted } = await deleter({ db, auth, uid });
        const check = await verifier({ db, auth, uid });
        result.docsDeleted = docsDeleted;
        result.authDeleted = authDeleted;
        result.verified = check.ok;
        result.problems = check.problems;
        await db.collection('deletionAudit').doc(`${runId}-${uidHash}`).set({
          uidHash,
          source: c.source,
          requestedAt: c.requestedAt,
          docsDeleted,
          authDeleted,
          verified: check.ok,
          outcome: docsDeleted === 0 && !authDeleted ? 'nothing-to-delete' : 'deleted',
          completedAt: FieldValue.serverTimestamp(),
        });
        if (!check.ok) {
          if (c.hasRequest) await releaseRequestClaim({ db, uid, runId });
          continue;
        }
        if (c.hasRequest) {
          await db.collection('deletionRequests').doc(uid).delete();
          removedRequests.add(uid);
        }
        result.ok = true;
      } catch (e) {
        if (c.hasRequest) {
          try {
            await releaseRequestClaim({ db, uid, runId });
          } catch (releaseError) {
            log(`Could not release deletion claim for ${uidHash}: ${releaseError.code ?? releaseError.message}`);
          }
        }
        result.error = e.code ?? e.message;
      }
    }
  }

  const pending = [...due, ...fresh].filter((r) => !removedRequests.has(r.uid) && !skippedRequests.has(r.uid));
  const stale = pending.filter((r) => now.getTime() - r.requestedAt.getTime() > STALE_MS).length;
  if (stale > 0) log(`ALERT: ${stale} request(s) older than 3 days are still pending.`);

  const failed = results.filter((r) => !r.ok && !r.skipped).length;
  const exitCode = refused ? 2 : failed > 0 || stale > 0 ? 1 : 0;
  const processedUids = dryRun ? [] : [...candidates.keys()].filter((_, i) => results[i]?.ok && !results[i]?.skipped);

  if (!dryRun) {
    await db.collection('deletionRuns').doc(runId).set({
      runId,
      refused,
      candidates: candidates.size,
      processed: processedUids.length,
      failed,
      staleRequests: stale,
      ok: exitCode === 0,
      completedAt: FieldValue.serverTimestamp(),
    });
  }
  return { exitCode, refused, results, processedUids, stale };
}

/** Operator email fallback: turns an email into a normal queue entry. Deletes nothing. */
export async function requestByEmail({ db, auth, email, dryRun = true, log = console.log }) {
  const user = await auth.getUserByEmail(email);
  log(`Found account ${hashUid(user.uid)} for the given email.`);
  if (dryRun) return { created: false };
  await db.collection('deletionRequests').doc(user.uid).set({
    requestedAt: FieldValue.serverTimestamp(),
    source: 'app',
    version: 1,
  });
  return { created: true };
}

function summary(out) {
  const rows = out.results.map(
    (r) => `| ${r.uidHash} | ${r.source} | ${r.docsDeleted ?? r.docsToDelete ?? '-'} | ${r.verified ?? '-'} | ${r.skipped ?? (r.ok ? 'ok' : (r.error ?? (r.problems ?? []).join('; ')) || 'FAILED')} |`,
  );
  return ['## Account deletion', '', '| uid hash | source | docs | verified | result |', '|---|---|---|---|---|', ...rows, ''].join('\n');
}

async function main() {
  const env = process.env;
  initializeApp({ credential: applicationDefault(), projectId: env.GCLOUD_PROJECT || 'invtracker-b19d1' });
  const db = getFirestore();
  const auth = getAuth();
  const dryRun = env.DRY_RUN !== 'false';
  const runId = `${env.GITHUB_RUN_ID ?? Date.now()}-${env.GITHUB_RUN_ATTEMPT ?? 1}`;

  if (env.REQUEST_EMAIL) {
    const { created } = await requestByEmail({ db, auth, email: env.REQUEST_EMAIL, dryRun });
    console.log(created ? 'Request created; it is processed after the 24 h window.' : 'Dry run: no request created.');
    return 0;
  }

  const out = await runJob({
    db,
    auth,
    runId,
    dryRun,
    force: env.FORCE === 'true',
    maxPerRun: Number(env.MAX_PER_RUN || 25),
    sweepGuestsDays: Number(env.SWEEP_INACTIVE_GUESTS || 0),
  });
  if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, summary(out));
  if (env.GITHUB_OUTPUT) {
    appendFileSync(env.GITHUB_OUTPUT, `run_id=${runId}\nuids=${out.processedUids.join(',')}\n`);
  }
  return out.exitCode;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().then(
    (code) => process.exit(code),
    (e) => {
      console.error(e);
      process.exit(1);
    },
  );
}
