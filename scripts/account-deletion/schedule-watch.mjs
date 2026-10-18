// Watches the account-deletion schedule from outside the job: the job's own 3-day alert cannot fire when no job runs.
// Needs no cloud credentials. It reads the Actions run list and files the same `account-deletion` issue the job does.
import { pathToFileURL } from 'node:url';

const LABEL = 'account-deletion';
const WORKFLOW = 'account-deletion.yml';

/** True when no successful scheduled run started within maxAgeMs of now. Skipped runs (variable unset) are not successes. */
export function isStale(runs, nowMs, maxAgeMs) {
  const newest = Math.max(...runs.map((r) => Date.parse(r.run_started_at)).filter(Number.isFinite), -Infinity);
  return !(nowMs - newest <= maxAgeMs);
}

async function main(env) {
  if (env.SCHEDULE_ENABLED !== 'true') {
    console.log('::notice::ACCOUNT_DELETION_SCHEDULE_ENABLED is not true, so the schedule is off and there is nothing to watch.');
    return 0;
  }
  const repo = env.GITHUB_REPOSITORY;
  const maxHours = Number(env.MAX_AGE_HOURS || 48);
  const api = async (path, init = {}) => {
    const res = await fetch(`https://api.github.com/repos/${repo}${path}`, {
      ...init,
      headers: { authorization: `Bearer ${env.GITHUB_TOKEN}`, accept: 'application/vnd.github+json', 'x-github-api-version': '2022-11-28' },
    });
    return res;
  };
  const list = await api(`/actions/workflows/${WORKFLOW}/runs?event=schedule&branch=main&status=success&per_page=5`);
  if (!list.ok) throw new Error(`run list failed: ${list.status}`);
  const { workflow_runs: runs } = await list.json();
  if (!isStale(runs, Date.now(), maxHours * 3600e3)) {
    console.log(`Newest successful scheduled run is within ${maxHours}h.`);
    return 0;
  }
  const runUrl = `${env.GITHUB_SERVER_URL}/${repo}/actions/runs/${env.GITHUB_RUN_ID}`;
  const status = `No successful scheduled run of ${WORKFLOW} in the last ${maxHours} hours although ACCOUNT_DELETION_SCHEDULE_ENABLED is true.\nWatchdog run: ${runUrl}`;
  console.log(`::error::${status.split('\n')[0]}`);
  const json = { 'content-type': 'application/json' };
  if ((await api(`/labels/${LABEL}`)).status === 404) {
    await api('/labels', { method: 'POST', headers: json, body: JSON.stringify({ name: LABEL, color: 'B60205', description: 'The account-deletion job needs attention' }) });
  }
  const open = await (await api(`/issues?labels=${LABEL}&state=open&per_page=30`)).json();
  const existing = open.find((i) => !i.pull_request);
  if (existing) {
    await api(`/issues/${existing.number}/comments`, { method: 'POST', headers: json, body: JSON.stringify({ body: `The schedule looks stopped.\n\n${status}` }) });
  } else {
    const body = [
      'The account-deletion schedule appears to have stopped, so requests may be waiting past the 7-day promise.',
      '',
      status,
      '',
      'Check, in order: the Actions tab (GitHub pauses scheduled workflows of a public repo after 60 days without activity: re-enable the workflow), the repo variable ACCOUNT_DELETION_SCHEDULE_ENABLED, and the default branch name. Then run the workflow by hand.',
      '',
      'This issue deliberately holds no user id, email or name.',
    ].join('\n');
    await api('/issues', { method: 'POST', headers: json, body: JSON.stringify({ title: 'Account-deletion schedule has stopped', labels: [LABEL], body }) });
  }
  return 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main(process.env).then((code) => process.exit(code), (e) => { console.error(`::error::watchdog failed (${e.message})`); process.exit(1); });
}
