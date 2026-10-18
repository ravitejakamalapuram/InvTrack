// The schedule watchdog must not depend on the job it watches: no Google credentials, minimal token rights, and a
// staleness rule that only counts a successful scheduled run.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parse } from 'yaml';
import { isStale } from '../schedule-watch.mjs';

const raw = readFileSync(new URL('../../../.github/workflows/account-deletion-watchdog.yml', import.meta.url), 'utf8');
const wf = parse(raw);
const HOUR = 3600e3;
const now = Date.parse('2026-10-18T12:00:00Z');
const ago = (h) => new Date(now - h * HOUR).toISOString();
const MAX = 48 * HOUR;

describe('isStale', () => {
  it('is stale with no successful scheduled run', () => assert.equal(isStale([], now, MAX), true));
  it('is fresh when the newest success is 20h old', () => assert.equal(isStale([{ run_started_at: ago(20) }], now, MAX), false));
  it('is fresh at exactly 48h, stale just past it', () => {
    assert.equal(isStale([{ run_started_at: ago(48) }], now, MAX), false);
    assert.equal(isStale([{ run_started_at: ago(48.01) }], now, MAX), true);
  });
  it('uses the newest run whatever the order', () => assert.equal(isStale([{ run_started_at: ago(100) }, { run_started_at: ago(5) }], now, MAX), false));
  it('treats an unreadable date as stale', () => assert.equal(isStale([{ run_started_at: 'nope' }], now, MAX), true));
});

describe('account-deletion-watchdog.yml', () => {
  const job = Object.values(wf.jobs)[0];
  it('has no workflow-wide rights and only the three it needs', () => {
    assert.deepEqual(wf.permissions, {});
    assert.deepEqual(job.permissions, { contents: 'read', actions: 'read', issues: 'write' });
  });
  it('never asks for a cloud login', () => assert.doesNotMatch(raw, /id-token|google-github-actions|workload_identity/));
  it('runs daily on main in this repository only', () => {
    assert.match(wf.on.schedule[0].cron, /^\d+ \d+ \* \* \*$/);
    assert.match(job.if, /github\.ref == 'refs\/heads\/main'/);
    assert.match(job.if, /github\.repository == 'ravitejakamalapuram\/InvTrack'/);
  });
  it('pins every action to a SHA and checks out without credentials', () => {
    const uses = [...raw.matchAll(/uses:\s*(\S+)/g)].map((m) => m[1]);
    assert.ok(uses.length > 0);
    for (const u of uses) assert.match(u, /@[0-9a-f]{40}$/, u);
    assert.match(raw, /persist-credentials: false/);
  });
  it('keeps ${{ }} out of scripts', () => {
    for (const s of job.steps.filter((x) => x.run)) assert.doesNotMatch(s.run, /\$\{\{/);
  });
});
