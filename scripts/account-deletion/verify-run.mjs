// Independent read-back job: a fresh process that re-checks what the deletion run reported.
import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { COOLING_MS, findOrphans } from './sweep.mjs';
import { verifyUserGone } from './verify.mjs';

const DAY_MS = 24 * 60 * 60 * 1000;

export async function verifyRun({ db, auth, runId, uids, now = new Date() }) {
  const problems = [];

  for (const uid of uids) {
    const r = await verifyUserGone({ db, auth, uid });
    r.problems.forEach((p) => problems.push(`processed account: ${p}`));
  }

  const runDoc = await db.collection('deletionRuns').doc(runId).get();
  if (!runDoc.exists) problems.push('deletionRuns record for this run is missing');
  else if (runDoc.get('refused') !== false) problems.push('deletionRuns record says the run was refused');

  const orphans = await findOrphans(db, auth);
  if (orphans.length > 0) problems.push(`${orphans.length} orphaned users/<uid> tree(s) still exist`);

  const limit = now.getTime() - COOLING_MS - DAY_MS;
  const requests = await db.collection('deletionRequests').get();
  const old = requests.docs.filter((d) => (d.get('requestedAt')?.toDate?.().getTime() ?? 0) < limit);
  if (old.length > 0) problems.push(`${old.length} deletion request(s) older than cooling + 1 day remain`);

  return { ok: problems.length === 0, problems };
}

async function main() {
  const env = process.env;
  initializeApp({ credential: applicationDefault(), projectId: env.GCLOUD_PROJECT || 'invtracker-b19d1' });
  const uids = (env.UIDS ?? '').split(',').filter(Boolean);
  const out = await verifyRun({ db: getFirestore(), auth: getAuth(), runId: env.RUN_ID, uids });
  const text = out.ok ? 'verify: all checks passed' : `verify: MISMATCH\n${out.problems.map((p) => `- ${p}`).join('\n')}`;
  console.log(text);
  if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `## Verify\n\n${text}\n`);
  return out.ok ? 0 : 1;
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
