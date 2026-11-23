// Writes today's gold and silver rates to metalRates/latest.
//
//   node run.mjs --dry-run   read both sources and print what would be written (no Firestore, no login)
//   node run.mjs             write it (Admin SDK, keyless Google login in the workflow)
//
// Only the sides that were read are written (merge), so a source that fails keeps its last good value in the
// document. If both fail, the run fails so it is noticed.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { buildUpdate, fetchRates } from './lib.mjs';

const dryRun = process.argv.includes('--dry-run');
const result = await fetchRates(fetch);
for (const e of result.errors) console.log(`::warning::${e}`);

const update = buildUpdate(result);
if (!update) {
  console.log('::error::No rate could be read from either source.');
  process.exit(1);
}

const show = (side) =>
  side && `gold ${side.gold.toFixed(4)}, silver ${side.silver.toFixed(4)}, at ${side.updatedAt.toISOString()}`;
console.log(`India selling rate (INR per gram): ${show(update.inr) ?? 'not updated'}`);
console.log(`International rate (USD per gram): ${show(update.usd) ?? 'not updated'}`);

if (dryRun) {
  console.log('Dry run: nothing written.');
} else {
  // firebase-admin is installed under scripts/account-deletion (the job's shared dependencies).
  const require = createRequire(join(dirname(fileURLToPath(import.meta.url)), '../account-deletion/'));
  const { applicationDefault, initializeApp } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  initializeApp({ credential: applicationDefault(), projectId: process.env.GCLOUD_PROJECT || 'invtracker-b19d1' });
  await getFirestore().doc('metalRates/latest').set(update, { merge: true });
  console.log('Wrote metalRates/latest.');
}
