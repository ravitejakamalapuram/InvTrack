// Account-deletion job. See README.md. Every phase is idempotent; the request document is
// deleted last so a crash leaves it for the next run.
import { createHash } from 'node:crypto';
import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { countDocs, deleteUserData } from './delete.mjs';
import { findInactiveGuests, findOrphans, loadRequests, STALE_MS } from './sweep.mjs';
import { verifyUserGone } from './verify.mjs';

export const hashUid = (uid) => createHash('sha256').update(uid).digest('hex').slice(0, 16);

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
        const { docsDeleted, authDeleted } = await deleter({ db, auth, uid });
        const check = await verifier({ db, auth, uid });
        result.docsDeleted = docsDeleted;
        result.authDeleted = authDeleted;
        result.verified = check.ok;
        result.problems = check.problems;
        await db.collection('deletionAudit').doc(`${runId}-${uidHash}`).set({
          runId,
          uidHash,
          source: c.source,
          requestedAt: c.requestedAt,
          docsDeleted,
          authDeleted,
          verified: check.ok,
          outcome: docsDeleted === 0 && !authDeleted ? 'nothing-to-delete' : 'deleted',
          completedAt: FieldValue.serverTimestamp(),
        });
        if (!check.ok) continue;
        if (c.hasRequest) {
          await db.collection('deletionRequests').doc(uid).delete();
          removedRequests.add(uid);
        }
        result.ok = true;
      } catch (e) {
        result.error = e.code ?? e.message;
      }
    }
  }

  const pending = [...due, ...fresh].filter((r) => !removedRequests.has(r.uid));
  const stale = pending.filter((r) => now.getTime() - r.requestedAt.getTime() > STALE_MS).length;
  if (stale > 0) log(`ALERT: ${stale} request(s) older than 3 days are still pending.`);

  const failed = results.filter((r) => !r.ok).length;
  const exitCode = refused ? 2 : failed > 0 || stale > 0 ? 1 : 0;

  if (!dryRun) {
    await db.collection('deletionRuns').doc(runId).set({
      runId,
      refused,
      candidates: candidates.size,
      processed: results.filter((r) => r.ok).length,
      failed,
      staleRequests: stale,
      ok: exitCode === 0,
      completedAt: FieldValue.serverTimestamp(),
    });
  }
  return { exitCode, refused, results, stale };
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
    (r) => `| ${r.uidHash} | ${r.source} | ${r.docsDeleted ?? r.docsToDelete ?? '-'} | ${r.verified ?? '-'} | ${r.ok ? 'ok' : (r.error ?? (r.problems ?? []).join('; ')) || 'FAILED'} |`,
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
  // Announced first, before anything is deleted, so the verify job still runs if this job dies part-way. It is the
  // only thing handed on: the accounts are found again by their hashed audit records, never by uid.
  if (env.GITHUB_OUTPUT) appendFileSync(env.GITHUB_OUTPUT, `run_id=${runId}\n`);

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
