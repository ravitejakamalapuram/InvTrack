// Files one GitHub issue per new Crashlytics crash (labelled `crash`) so the issue loop can fix it.
// No dependencies: Node 20 fetch + crypto. Env: FIREBASE_CRASH_SA_JSON (read-only service account),
// GITHUB_TOKEN, GITHUB_REPOSITORY, optional DRY_RUN=1, WINDOW_DAYS (default 7), MAX_NEW (default 5).
import { createSign } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const PROJECT = 'invtracker-b19d1';
const APP_ID = '1:784857267556:android:5ba7e064263d78f61dce71';
const API = `https://firebasecrashlytics.googleapis.com/v1alpha/projects/${PROJECT}/apps/${APP_ID}`;
const MARK = 'crashlytics-issue';

const b64 = (v) => Buffer.from(v).toString('base64url');

async function accessToken(sa) {
  const now = Math.floor(Date.now() / 1000);
  const head = b64(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64(JSON.stringify({
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/cloud-platform',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  }));
  const sig = createSign('RSA-SHA256').update(`${head}.${claim}`).sign(sa.private_key).toString('base64url');
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${head}.${claim}.${sig}` }),
  });
  if (!res.ok) throw new Error(`token request failed: HTTP ${res.status}`);
  return (await res.json()).access_token;
}

async function crashlytics(token, path, params) {
  const url = new URL(`${API}/${path}`);
  for (const [k, v] of params) url.searchParams.append(k, v);
  const res = await fetch(url, { headers: { authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`Crashlytics ${path} failed: HTTP ${res.status} ${(await res.text()).slice(0, 300)}`);
  return res.json();
}

const sum = (metrics, key) => (metrics ?? []).reduce((n, m) => n + Number(m[key] ?? 0), 0);

export function frameLine(f) {
  const where = f.file ? `${f.file}${f.line ? `:${f.line}` : ''}` : (f.library ?? '');
  return `${f.blamed ? '>> ' : '   '}${f.symbol ?? f.address ?? '?'}${where ? `  (${where})` : ''}`;
}

// No user id, installation id, session id, event id or custom keys: privacy rule 7 and a public repo.
export function buildBody(group, event) {
  const i = group.issue;
  const lines = [];
  lines.push(`<!-- ${MARK}:${i.id} -->`);
  lines.push(`**Crashlytics issue** \`${i.id}\` · ${i.errorType ?? 'FATAL'} · state ${i.state ?? 'unknown'}${i.uri ? ` · [Console](${i.uri})` : ''}`);
  lines.push('');
  lines.push(`- Events in window: ${sum(group.metrics, 'eventsCount')}, users impacted: ${sum(group.metrics, 'impactedUsersCount')}`);
  lines.push(`- First seen ${i.firstSeenTime ?? '?'} (version ${i.firstSeenVersion ?? '?'}), last seen ${i.lastSeenTime ?? '?'} (version ${i.lastSeenVersion ?? '?'})`);
  if (i.signals?.length) lines.push(`- Signals: ${i.signals.join(', ')}`);
  if (event) {
    const dev = event.device?.model ?? event.device?.displayName ?? event.device?.manufacturer;
    lines.push(`- Latest sample: app ${event.version?.displayVersion ?? event.version?.displayName ?? '?'}, OS ${event.operatingSystem?.displayName ?? '?'}, device ${dev ?? '?'}, ${event.eventTime ?? ''}`);
    lines.push('');
    for (const ex of event.exceptions ?? []) {
      lines.push(`**${ex.type ?? 'Exception'}**: ${ex.exceptionMessage ?? ex.title ?? ''}`);
      lines.push('```', ...(ex.frames ?? []).slice(0, 60).map(frameLine), '```');
    }
    const crashed = (event.threads ?? []).filter((t) => t.crashed || t.blamed);
    for (const t of crashed.slice(0, 2)) {
      lines.push(`**Thread ${t.name ?? t.title ?? ''}** ${t.signal ?? ''}`);
      lines.push('```', ...(t.frames ?? []).slice(0, 60).map(frameLine), '```');
    }
    if (event.blameFrame) lines.push(`Blamed frame: \`${frameLine(event.blameFrame).trim()}\``);
    const logs = (event.logs ?? []).slice(-30).map((l) => l.message ?? JSON.stringify(l));
    if (logs.length) lines.push('<details><summary>Last log lines</summary>', '', '```', ...logs, '```', '</details>');
  } else {
    lines.push('', '_No sample event could be fetched; open the Console link._');
  }
  lines.push('', 'Fix per `docs/runbooks/CRASH_FIX_ROUTINE.md`: triage against current `main` first, test first, close this issue from the PR.');
  return lines.join('\n');
}

async function gh(method, path, body) {
  const res = await fetch(`https://api.github.com/repos/${process.env.GITHUB_REPOSITORY}${path}`, {
    method,
    headers: { authorization: `Bearer ${process.env.GITHUB_TOKEN}`, accept: 'application/vnd.github+json', 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(`GitHub ${method} ${path} failed: HTTP ${res.status}`);
  return res.json();
}

async function knownIds() {
  const ids = new Set();
  for (let page = 1; page < 20; page++) {
    const rows = await gh('GET', `/issues?labels=crash&state=all&per_page=100&page=${page}`);
    for (const r of rows) for (const m of (r.body ?? '').matchAll(new RegExp(`<!-- ${MARK}:(\\S+) -->`, 'g'))) ids.add(m[1]);
    if (rows.length < 100) break;
  }
  return ids;
}

async function main() {
  const dry = process.env.DRY_RUN === '1';
  const sa = JSON.parse(process.env.FIREBASE_CRASH_SA_JSON ?? 'null');
  if (!sa) { console.log('FIREBASE_CRASH_SA_JSON is not set; nothing to do.'); return; }
  const token = await accessToken(sa);
  const days = Number(process.env.WINDOW_DAYS ?? 7);
  const max = Number(process.env.MAX_NEW ?? 5);
  const end = new Date(), start = new Date(end - days * 864e5);
  const report = await crashlytics(token, 'reports/topIssues', [
    ['filter.interval.startTime', start.toISOString()], ['filter.interval.endTime', end.toISOString()],
    ['filter.issue.errorTypes', 'FATAL'], ['filter.issue.errorTypes', 'ANR'], ['pageSize', '25'],
  ]);
  const groups = (report.groups ?? []).filter((g) => g.issue && g.issue.state !== 'CLOSED');
  const known = dry && !process.env.GITHUB_TOKEN ? new Set() : await knownIds();
  const fresh = groups.filter((g) => !known.has(g.issue.id)).slice(0, max);
  console.log(`${groups.length} open crash issues in ${days} d, ${fresh.length} new to file`);
  for (const g of fresh) {
    let event = null;
    try {
      const ev = await crashlytics(token, 'events', [['filter.issue.id', g.issue.id], ['pageSize', '1']]);
      event = ev.events?.[0] ?? null;
    } catch (e) { console.log(`sample event unavailable for ${g.issue.id}: ${e.message}`); }
    const title = `[crash ${g.issue.id.slice(0, 8)}] ${g.issue.title ?? 'Crash'} ${g.issue.subtitle ? `in ${g.issue.subtitle}` : ''}`.slice(0, 200);
    const body = buildBody(g, event);
    if (dry) { console.log(`--- would file: ${title}\n${body}\n`); continue; }
    const made = await gh('POST', '/issues', { title, body, labels: ['crash'] });
    console.log(`filed #${made.number} for ${g.issue.id}`);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main().catch((e) => { console.error(e.message); process.exit(1); });
}
