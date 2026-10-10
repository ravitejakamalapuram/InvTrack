// Guards the safety properties of .github/workflows/account-deletion.yml. It needs no emulator: it parses the YAML,
// pins the job gates and the step env to their exact text, and runs the real "mode" step shell over a truth table
// (bash and jq, both on the GitHub runner). Each rule returns a list of problems; the second block proves every rule
// can fail by feeding it a deliberately unsafe copy of the real workflow.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parse } from 'yaml';

const raw = readFileSync(new URL('../../../.github/workflows/account-deletion.yml', import.meta.url), 'utf8');
const real = parse(raw);

const MODE_DRY_RUN = "${{ github.event_name == 'schedule' && 'false' || inputs.dry_run }}";
const FORCE = "${{ github.event_name == 'schedule' && 'false' || inputs.force }}";
const INPUT_MAX = "${{ inputs.max_per_run || '25' }}";
const INPUT_SWEEP = "${{ inputs.sweep_inactive_guests_days || '0' }}";
// The exact gates. Substring checks let `... || true` or a dropped clause through, so these are compared whole.
const RUN_IF =
  "github.ref == 'refs/heads/main' && github.repository == 'ravitejakamalapuram/InvTrack' && " +
  "(github.event_name != 'schedule' || vars.ACCOUNT_DELETION_SCHEDULE_ENABLED == 'true') && " +
  "(github.event_name == 'schedule' || github.run_attempt == '1')";
const VERIFY_IF =
  "always() && github.ref == 'refs/heads/main' && (needs.run.result == 'success' || needs.run.result == 'failure') && " +
  "needs.run.outputs.live == 'true' && needs.run.outputs.run_id != ''";
const MODE_ENV = { DRY_RUN: MODE_DRY_RUN, MAX_PER_RUN: INPUT_MAX, SWEEP_DAYS: INPUT_SWEEP };
const DELETION_ENV = {
  DRY_RUN: '${{ steps.mode.outputs.dry_run }}',
  FORCE,
  MAX_PER_RUN: INPUT_MAX,
  SWEEP_INACTIVE_GUESTS: INPUT_SWEEP,
  REQUEST_EMAIL: '${{ inputs.request_email }}',
  GA4_PROPERTY_ID: '${{ vars.GA4_PROPERTY_ID }}',
};
const VERIFY_ENV = { RUN_ID: '${{ needs.run.outputs.run_id }}' };
const RUN_OUTPUTS = { live: '${{ steps.mode.outputs.live }}', run_id: '${{ steps.deletion.outputs.run_id }}' };
const PINNED = /^[\w.-]+\/[\w.-]+(\/[\w./-]+)?@[0-9a-f]{40}$/;
// Any way to reach a dispatch input or the event payload from inside a script: dotted, bracketed, or head_ref.
const USER_CONTROLLED = /\binputs\b|\bgithub\s*(\.event\b|\[)|head_ref/;

const jobsOf = (doc) => Object.entries(doc.jobs ?? {});
const stepsOf = (doc) => jobsOf(doc).flatMap(([job, j]) => (j.steps ?? []).map((step) => ({ job, step })));
const scriptsOf = (doc) =>
  stepsOf(doc).flatMap(({ job, step }) => [
    ...(step.run ? [{ job, text: step.run }] : []),
    ...(step.with?.script ? [{ job, text: step.with.script }] : []),
  ]);
const expressions = (text) => [...text.matchAll(/\$\{\{([\s\S]*?)\}\}/g)].map((m) => m[1]);
const canon = (v) => JSON.stringify(v, (_, x) => (x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort()) : x));
const same = (a, b) => canon(a) === canon(b);
const norm = (v) => String(v ?? '').replace(/\s+/g, ' ').trim();
const stepById = (doc, id) => stepsOf(doc).find(({ step }) => step.id === id)?.step;

/** Runs the real "mode" step script the way the runner does (bash -e) and returns what it printed and wrote. */
function runMode(doc, { event = 'dispatch', dryRun, maxPerRun = '25', sweepDays = '0', email = '' }) {
  const dir = mkdtempSync(join(tmpdir(), 'mode-step-'));
  try {
    const eventFile = join(dir, 'event.json');
    const outFile = join(dir, 'output');
    writeFileSync(eventFile, JSON.stringify(event === 'schedule' ? { schedule: '41 20 * * *' } : { inputs: { request_email: email } }));
    writeFileSync(outFile, '');
    const r = spawnSync('bash', ['-e', '-c', stepById(doc, 'mode')?.run ?? 'exit 99'], {
      env: { PATH: process.env.PATH, DRY_RUN: dryRun, MAX_PER_RUN: maxPerRun, SWEEP_DAYS: sweepDays, GITHUB_EVENT_PATH: eventFile, GITHUB_OUTPUT: outFile },
      encoding: 'utf8',
    });
    const written = readFileSync(outFile, 'utf8');
    return {
      status: r.status,
      log: `${r.stdout}${r.stderr}`,
      written,
      outputs: Object.fromEntries(written.split('\n').filter(Boolean).map((l) => l.split('='))),
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const rules = {
  permissions(doc) {
    const want = { run: { contents: 'read', 'id-token': 'write' }, verify: { contents: 'read', 'id-token': 'write' }, notify: { issues: 'write' } };
    const out = same(doc.permissions, {}) ? [] : ['top-level permissions must be {}'];
    for (const [name, job] of jobsOf(doc)) {
      if (!want[name]) out.push(`unexpected job ${name}`);
      else if (!same(job.permissions, want[name])) out.push(`job ${name} permissions must be ${JSON.stringify(want[name])}`);
    }
    return out;
  },

  triggers(doc) {
    const out = same(Object.keys(doc.on).sort(), ['schedule', 'workflow_dispatch']) ? [] : ['only schedule and workflow_dispatch may trigger it'];
    if (doc.on.schedule?.length !== 1 || !/^\d{1,2} \d{1,2} \* \* \*$/.test(doc.on.schedule[0].cron ?? '')) out.push('schedule must be one daily cron (fixed minute and hour)');
    return out;
  },

  scheduleGate(doc) {
    const out = [];
    if (norm(doc.jobs.run?.if) !== RUN_IF) {
      out.push(`run job gate must be exactly: ${RUN_IF} (main only; the schedule needs ACCOUNT_DELETION_SCHEDULE_ENABLED; a manual dispatch only on its first attempt, because a re-run replays old inputs on old code)`);
    }
    if (![doc.jobs.verify?.needs].flat().includes('run')) out.push('verify must need run');
    if (![doc.jobs.notify?.needs].flat().includes('run')) out.push('notify must need run');
    if (norm(doc.jobs.verify?.if) !== VERIFY_IF) out.push(`verify job gate must be exactly: ${VERIFY_IF}`);
    if (doc.jobs.notify?.if !== 'failure()') out.push('notify must run only on failure()');
    if (stepsOf(doc).some(({ job, step }) => job === 'notify' && step.uses?.startsWith('actions/checkout'))) out.push('notify must not check out code');
    return out;
  },

  mainOnly(doc) {
    return ['run', 'verify'].filter((j) => !(doc.jobs[j]?.if ?? '').includes("github.ref == 'refs/heads/main'")).map((j) => `job ${j} must run on refs/heads/main only`);
  },

  dryRunDefault(doc) {
    const out = [];
    const inputs = doc.on.workflow_dispatch?.inputs ?? {};
    if (inputs.dry_run?.type !== 'boolean' || inputs.dry_run?.default !== true) out.push('dry_run must be a boolean defaulting to true');
    if (inputs.force?.default !== false) out.push('force must default to false');
    if (String(inputs.max_per_run?.default) !== '25') out.push('max_per_run must default to 25');
    if (inputs.sweep_inactive_guests_days?.default !== '0') out.push('the guest sweep must default to off');
    return out;
  },

  // Every env value of the steps that decide what is deleted, compared whole: a fixed cap, a sweep that is on by
  // default, a dispatch that is live by default, or an email that reaches a step early all show up here.
  stepEnv(doc) {
    const out = [];
    if (!same(stepById(doc, 'mode')?.env, MODE_ENV)) out.push(`mode step env must be exactly ${JSON.stringify(MODE_ENV)} (only a schedule may be live; a dispatch uses the dry_run input)`);
    if (!same(stepById(doc, 'deletion')?.env, DELETION_ENV)) out.push(`Delete accounts env must be exactly ${JSON.stringify(DELETION_ENV)} (DRY_RUN from the mode step; force false on a schedule; the cap and the sweep from the inputs)`);
    const verify = stepsOf(doc).find(({ job, step }) => job === 'verify' && step.name === 'Verify the run')?.step;
    if (!same(verify?.env, VERIFY_ENV)) out.push(`Verify the run env must be exactly ${JSON.stringify(VERIFY_ENV)}: no uid is passed between jobs`);
    return out;
  },

  // The run job hands on the run id and the live flag, nothing else. A uid in a job output or a step env is printed in
  // the (public) log header, and a masked output is dropped.
  noRawUids(doc, text) {
    const out = [];
    if (!same(doc.jobs.run?.outputs, RUN_OUTPUTS)) out.push(`run job outputs must be exactly ${JSON.stringify(RUN_OUTPUTS)}`);
    if (/outputs\.uids|\bUIDS\b/.test(text)) out.push('uids must not travel between jobs');
    return out;
  },

  // Runs the real mode step. Only an explicit 'false' is live, an email request is never live, bad numbers stop the run
  // before it decides anything, and the email is masked before anything else could print it.
  modeScript(doc) {
    const out = [];
    const want = (name, got, dryRun, live) => {
      if (got.status !== 0) out.push(`${name}: exited ${got.status}\n${got.log}`);
      else if (got.outputs.dry_run !== dryRun || got.outputs.live !== live) out.push(`${name}: wrote dry_run=${got.outputs.dry_run} live=${got.outputs.live}, want dry_run=${dryRun} live=${live}`);
    };
    want('manual dispatch, dry_run ticked', runMode(doc, { dryRun: 'true' }), 'true', 'false');
    want('manual dispatch, dry_run unticked', runMode(doc, { dryRun: 'false' }), 'false', 'true');
    want('schedule', runMode(doc, { event: 'schedule', dryRun: 'false' }), 'false', 'true');
    for (const v of ['', 'no', 'False', '0', 'yes']) want(`DRY_RUN=${JSON.stringify(v)} is a dry run`, runMode(doc, { dryRun: v }), 'true', 'false');
    want('an email request is never live', runMode(doc, { dryRun: 'false', email: 'person@example.com' }), 'false', 'false');
    want('an email request on a dry run', runMode(doc, { dryRun: 'true', email: 'person@example.com' }), 'true', 'false');

    for (const sweepDays of ['abc', '-1', '10000', '1.5', '1 2']) {
      const r = runMode(doc, { dryRun: 'false', sweepDays });
      if (r.status === 0 || r.written !== '') out.push(`sweep_inactive_guests_days=${JSON.stringify(sweepDays)} must stop the run before it decides anything`);
    }
    for (const maxPerRun of ['0', 'abc', '10000', '-5', '2 5', '']) {
      const r = runMode(doc, { dryRun: 'false', maxPerRun });
      if (r.status === 0 || r.written !== '') out.push(`max_per_run=${JSON.stringify(maxPerRun)} must stop the run before it decides anything`);
    }

    const email = 'person@example.com';
    const ok = runMode(doc, { dryRun: 'false', email });
    const lines = ok.log.split('\n').filter((l) => l.includes(email));
    if (!same(lines, [`::add-mask::${email}`])) out.push(`the email must reach the log only as its own ::add-mask:: line, got ${JSON.stringify(lines)}`);
    if (ok.written.includes(email)) out.push('the email must not be written to GITHUB_OUTPUT');
    // A rejected value is never echoed, not even its later lines: an ::add-mask:: line only masks up to the newline.
    for (const bad of ['two words@example.com', 'no-at-sign', 'a@b@c', 'a@b.com\nsecond-line', ' ']) {
      const r = runMode(doc, { dryRun: 'false', email: bad });
      if (r.status === 0 || r.written !== '') out.push(`an email input of ${JSON.stringify(bad)} must stop the run`);
      const parts = bad.split('\n').filter((p) => p.trim());
      if (r.log.split('\n').some((l) => parts.some((p) => l.includes(p)))) out.push(`a rejected email input must not be echoed: ${JSON.stringify(bad)}`);
    }
    return out;
  },

  pinnedActions(doc, text) {
    const out = [];
    const uses = stepsOf(doc).flatMap(({ step }) => (step.uses ? [step.uses] : []));
    for (const u of uses) if (!PINNED.test(u)) out.push(`not pinned to a 40-character SHA: ${u}`);
    for (const [name, job] of jobsOf(doc)) if (job.uses) out.push(`job ${name} must not call a reusable workflow`);
    const lines = text.split('\n').filter((l) => /^\s*(-\s+)?uses:/.test(l));
    if (lines.length !== uses.length) out.push('every uses: must be a step');
    for (const l of lines) if (!/@[0-9a-f]{40} # v\d+(\.\d+){0,2}$/.test(l)) out.push(`needs a version comment: ${l.trim()}`);
    return out;
  },

  noInputsInScripts(doc) {
    const out = [];
    for (const { job, text } of scriptsOf(doc)) {
      for (const e of expressions(text)) if (USER_CONTROLLED.test(e)) out.push(`job ${job}: \${{ ${e.trim()} }} inside a script`);
    }
    return out;
  },

  requestEmailStaysPrivate(doc, text) {
    const out = [];
    const steps = stepsOf(doc);
    const modeAt = steps.findIndex(({ step }) => step.id === 'mode');
    const count = (t) => (t.match(/request_email/g) ?? []).length;
    const envUses = steps.map((s, at) => ({ ...s, at })).filter(({ step }) => Object.values(step.env ?? {}).some((v) => String(v).includes('request_email')));
    for (const { step, at } of envUses) {
      if (step.env.REQUEST_EMAIL !== '${{ inputs.request_email }}') out.push('request_email may only be passed as REQUEST_EMAIL');
      // A step prints its evaluated env before its first command runs, so a mask registered in the same step is too late.
      if (modeAt < 0 || at <= modeAt) out.push('the input may reach an env block only in a step after the mode step, which masks it');
    }
    const modeRun = steps[modeAt]?.step.run ?? '';
    if (count(modeRun) !== 1 || !modeRun.includes(`REQUEST_EMAIL=$(jq -r '.inputs.request_email // ""' "$GITHUB_EVENT_PATH")`)) out.push('the mode step must read the email once, from the event file');
    if (!modeRun.includes('echo "::add-mask::$REQUEST_EMAIL"')) out.push('the mode step must mask the email');
    if (count(text) !== 1 + envUses.length + count(modeRun)) {
      out.push('request_email may appear only as the input, as REQUEST_EMAIL in a later env, and in the one read in the mode step');
    }
    for (const { job, text: script } of scriptsOf(doc)) {
      for (const line of script.split('\n').filter((l) => /REQUEST_EMAIL/.test(l))) {
        if (/echo|printf|cat |tee|SUMMARY|OUTPUT/.test(line) && line.trim() !== 'echo "::add-mask::$REQUEST_EMAIL"') out.push(`job ${job}: REQUEST_EMAIL reaches a log, output or summary: ${line.trim()}`);
      }
    }
    for (const { job, text: script } of scriptsOf(doc)) if (/set\s+-\w*x|xtrace|bash -x/.test(script)) out.push(`job ${job}: tracing would print the email before it is masked`);
    for (const [name, job] of jobsOf(doc)) if (JSON.stringify(job.outputs ?? {}).includes('REQUEST_EMAIL')) out.push(`job ${name} output carries the email`);
    return out;
  },

  hardening(doc, text) {
    const out = [];
    if (doc.concurrency?.['cancel-in-progress'] !== false || !doc.concurrency?.group) out.push('one run at a time, never cancel a running deletion');
    for (const [name, job] of jobsOf(doc)) if (!(job['timeout-minutes'] > 0)) out.push(`job ${name} needs timeout-minutes`);
    for (const { job, step } of stepsOf(doc)) {
      if (step.uses?.startsWith('actions/checkout') && step.with?.['persist-credentials'] !== false) out.push(`job ${job}: checkout must set persist-credentials: false`);
      if (step.uses?.startsWith('actions/setup-node') && String(step.with?.['node-version']) !== '22') out.push(`job ${job}: node 22`);
    }
    const auth = stepsOf(doc).filter(({ step }) => step.uses?.startsWith('google-github-actions/auth'));
    if (auth.length !== 2) out.push('run and verify must each authenticate');
    for (const { step } of auth) {
      if (!step.with?.workload_identity_provider || step.with?.service_account !== 'account-deletion-bot@invtracker-b19d1.iam.gserviceaccount.com') out.push('keyless auth as the account-deletion bot');
      if ('credentials_json' in step.with) out.push('no stored credentials');
    }
    if (/secrets\./.test(text)) out.push('no secrets: the job is keyless');
    return out;
  },
};

describe('account-deletion workflow safety', () => {
  for (const [name, rule] of Object.entries(rules)) {
    it(`${name}: the real workflow has no problems`, () => assert.deepEqual(rule(real, raw), []));
  }
});

describe('each rule can fail', () => {
  const clone = () => structuredClone(real);
  const swap = (text, from, to) => {
    assert.ok(text.includes(from), `mutation target not found: ${from}`);
    return text.replace(from, to);
  };
  const mode = (d) => stepById(d, 'mode');
  const deletion = (d) => stepById(d, 'deletion');
  const verifyStep = (d) => d.jobs.verify.steps.find((s) => s.name === 'Verify the run');
  const editMode = (from, to) => (d) => (mode(d).run = swap(mode(d).run, from, to));

  // [rule, what is broken, how to break a copy of the workflow, optionally how to break its raw text]
  const unsafe = [
    ['permissions', 'top-level write permissions', (d) => (d.permissions = { contents: 'write' })],
    ['triggers', 'a pull_request trigger', (d) => (d.on.pull_request = {})],
    ['triggers', 'a cron that fires every minute', (d) => (d.on.schedule[0].cron = '* * * * *')],
    ['scheduleGate', 'no schedule variable', (d) => (d.jobs.run.if = "github.ref == 'refs/heads/main'")],
    ['scheduleGate', 'the schedule gate ORed with true', (d) => (d.jobs.run.if = swap(d.jobs.run.if, "== 'true')", "== 'true' || true)"))],
    ['scheduleGate', 'main OR a dispatch from any branch', (d) => (d.jobs.run.if = swap(d.jobs.run.if, "github.ref == 'refs/heads/main' &&", "github.ref == 'refs/heads/main' || github.event_name == 'workflow_dispatch' &&"))],
    ['scheduleGate', 'a re-run of a manual dispatch allowed', (d) => (d.jobs.run.if = swap(d.jobs.run.if, " && (github.event_name == 'schedule' || github.run_attempt == '1')", ''))],
    ['scheduleGate', 'verify without the live check', (d) => (d.jobs.verify.if = swap(d.jobs.verify.if, "needs.run.outputs.live == 'true' &&", ''))],
    ['scheduleGate', 'verify without the run result test', (d) => (d.jobs.verify.if = swap(d.jobs.verify.if, "(needs.run.result == 'success' || needs.run.result == 'failure') &&", ''))],
    ['scheduleGate', 'notify on always()', (d) => (d.jobs.notify.if = 'always()')],
    ['mainOnly', 'verify on any branch', (d) => (d.jobs.verify.if = 'always()')],
    ['dryRunDefault', 'dry_run defaulting to false', (d) => (d.on.workflow_dispatch.inputs.dry_run.default = false)],
    ['dryRunDefault', 'the guest sweep on by default', (d) => (d.on.workflow_dispatch.inputs.sweep_inactive_guests_days.default = '1')],
    ['stepEnv', 'the cap fixed at 100000', (d) => (deletion(d).env.MAX_PER_RUN = '100000')],
    ['stepEnv', 'a schedule that sweeps guests', (d) => (deletion(d).env.SWEEP_INACTIVE_GUESTS = "${{ inputs.sweep_inactive_guests_days || '1' }}")],
    ['stepEnv', 'force true on a schedule', (d) => (deletion(d).env.FORCE = '${{ inputs.force }}')],
    ['stepEnv', 'a dispatch that is live by default', (d) => (mode(d).env.DRY_RUN = "${{ github.event_name == 'schedule' && 'false' || 'false' }}")],
    ['stepEnv', 'an extra variable in the verify step', (d) => (verifyStep(d).env.UIDS = 'x')],
    ['noRawUids', 'a uids job output', (d) => (d.jobs.run.outputs.uids = '${{ steps.deletion.outputs.uids }}')],
    ['noRawUids', 'a UIDS variable in the text', () => {}, (t) => `${t}\n# UIDS`],
    ['modeScript', 'dry_run=false always written', editMode('echo "dry_run=$dry_run"', 'echo "dry_run=false"')],
    ['modeScript', 'anything but true is live', editMode('if [ "$DRY_RUN" = "false" ]', 'if [ "$DRY_RUN" != "true" ]')],
    ['modeScript', 'live=true always', editMode('if [ "$dry_run" = "false" ] && [ -z "$REQUEST_EMAIL" ]; then live=true; else live=false; fi', 'live=true')],
    ['modeScript', 'an email request that is live', editMode('[ -z "$REQUEST_EMAIL" ]', 'true')],
    ['modeScript', 'no sweep validation', editMode('[[ "$SWEEP_DAYS" =~ ^[0-9]{1,4}$ ]] ||', 'true ||')],
    ['modeScript', 'no cap validation', editMode('[[ "$MAX_PER_RUN" =~ ^[1-9][0-9]{0,3}$ ]] ||', 'true ||')],
    ['modeScript', 'no mask', editMode('echo "::add-mask::$REQUEST_EMAIL"', ':')],
    ['modeScript', 'a mask before the email is validated', (d) => (mode(d).run = swap(swap(mode(d).run, 'if [ -n "$REQUEST_EMAIL" ]; then', 'if [ -n "$REQUEST_EMAIL" ]; then\n  echo "::add-mask::$REQUEST_EMAIL"'), '  echo "::add-mask::$REQUEST_EMAIL"\nfi', 'fi'))],
    ['modeScript', 'no email validation', editMode('if ! [[ "$REQUEST_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]]; then', 'if false; then')],
    ['modeScript', 'the email written to the outputs', editMode('echo "live=$live" >> "$GITHUB_OUTPUT"', 'echo "live=$live" >> "$GITHUB_OUTPUT"; echo "e=$REQUEST_EMAIL" >> "$GITHUB_OUTPUT"')],
    ['noInputsInScripts', 'an input inside a script', (d) => (mode(d).run = 'echo "${{ inputs.max_per_run }}"')],
    ['requestEmailStaysPrivate', 'the email echoed into the step summary', (d) => (mode(d).run += '\necho "$REQUEST_EMAIL" >> "$GITHUB_STEP_SUMMARY"')],
    ['requestEmailStaysPrivate', 'the email in the env of the step that masks it', (d) => (mode(d).env.REQUEST_EMAIL = '${{ inputs.request_email }}')],
    ['requestEmailStaysPrivate', 'the mask removed', editMode('echo "::add-mask::$REQUEST_EMAIL"', ':')],
    ['requestEmailStaysPrivate', 'the email read from the env again', editMode(`REQUEST_EMAIL=$(jq -r '.inputs.request_email // ""' "$GITHUB_EVENT_PATH")`, 'REQUEST_EMAIL="${REQUEST_EMAIL:-}"')],
    ['hardening', 'a running deletion that can be cancelled', (d) => (d.concurrency['cancel-in-progress'] = true)],
    ['pinnedActions', 'an unpinned action', (d) => (d.jobs.run.steps[0].uses = 'actions/checkout@v4')],
  ];
  for (const [rule, what, breakDoc, breakText] of unsafe) {
    it(`${rule} reports ${what}`, () => {
      const doc = clone();
      breakDoc(doc);
      assert.notDeepEqual(rules[rule](doc, breakText ? breakText(raw) : raw), []);
    });
  }

  it('noInputsInScripts reports the bracket form', () => {
    const doc = clone();
    mode(doc).run = 'echo "${{ inputs[\'max_per_run\'] }}"';
    assert.notDeepEqual(rules.noInputsInScripts(doc), []);
  });
  it('requestEmailStaysPrivate reports shell tracing', () => {
    const doc = clone();
    mode(doc).run = `set -x\n${mode(doc).run}`;
    assert.notDeepEqual(rules.requestEmailStaysPrivate(doc, raw), []);
  });
  it('pinnedActions reports a missing version comment', () => {
    assert.notDeepEqual(rules.pinnedActions(real, raw.replace(/ # v4\.4\.0/, '')), []);
  });
  it('requestEmailStaysPrivate reports a second use of the input', () => {
    assert.notDeepEqual(rules.requestEmailStaysPrivate(real, `${raw}\n# ${'$'}{{ inputs.request_email }}`), []);
  });
});
