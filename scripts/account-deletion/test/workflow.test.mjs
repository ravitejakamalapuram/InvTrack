// Guards the safety properties of .github/workflows/account-deletion.yml. It needs no emulator: it only
// parses the YAML. Each rule returns a list of problems; the second block proves every rule can fail by
// feeding it a deliberately unsafe copy of the real workflow.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parse } from 'yaml';

const raw = readFileSync(new URL('../../../.github/workflows/account-deletion.yml', import.meta.url), 'utf8');
const real = parse(raw);

const MODE_DRY_RUN = "${{ github.event_name == 'schedule' && 'false' || inputs.dry_run }}";
const FORCE = "${{ github.event_name == 'schedule' && 'false' || inputs.force }}";
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
    if (!/^\S+( \S+){4}$/.test(doc.on.schedule?.[0]?.cron ?? '')) out.push('schedule needs one 5-field cron');
    return out;
  },

  scheduleGate(doc) {
    const out = [];
    const gate = doc.jobs.run?.if ?? '';
    if (!gate.includes("vars.ACCOUNT_DELETION_SCHEDULE_ENABLED == 'true'")) out.push('run job must be gated on ACCOUNT_DELETION_SCHEDULE_ENABLED');
    if (!gate.includes("github.event_name != 'schedule' ||")) out.push('the gate may only restrict the schedule event, never a manual dispatch');
    if (![doc.jobs.verify?.needs].flat().includes('run')) out.push('verify must need run');
    if (![doc.jobs.notify?.needs].flat().includes('run')) out.push('notify must need run');
    if (!(doc.jobs.verify?.if ?? '').includes('needs.run.result')) out.push('verify must check the result of run');
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
    const steps = stepsOf(doc).map((s) => s.step);
    const mode = steps.find((s) => s.id === 'mode');
    const deletion = steps.find((s) => s.id === 'deletion');
    if (mode?.env?.DRY_RUN !== MODE_DRY_RUN) out.push('only a schedule may be live; a dispatch must use the dry_run input');
    if (deletion?.env?.DRY_RUN !== '${{ steps.mode.outputs.dry_run }}') out.push('run.mjs must take DRY_RUN from the mode step');
    if (deletion?.env?.FORCE !== FORCE) out.push('force is false on a schedule and the input on a dispatch');
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
    const envUses = stepsOf(doc).filter(({ step }) => Object.values(step.env ?? {}).some((v) => String(v).includes('inputs.request_email')));
    for (const { step } of envUses) if (step.env.REQUEST_EMAIL !== '${{ inputs.request_email }}') out.push('request_email may only be passed as REQUEST_EMAIL');
    if ((text.match(/request_email/g) ?? []).length !== 1 + envUses.length) {
      out.push('request_email may appear only as the input and as REQUEST_EMAIL in env');
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
  const unsafe = {
    permissions: (d) => (d.permissions = { contents: 'write' }),
    triggers: (d) => (d.on.pull_request = {}),
    scheduleGate: (d) => (d.jobs.run.if = "github.ref == 'refs/heads/main'"),
    mainOnly: (d) => (d.jobs.verify.if = 'always()'),
    dryRunDefault: (d) => (d.on.workflow_dispatch.inputs.dry_run.default = false),
    noInputsInScripts: (d) => (d.jobs.run.steps[2].run = 'echo "${{ inputs.max_per_run }}"'),
    requestEmailStaysPrivate: (d) => (d.jobs.run.steps[2].run += '\necho "$REQUEST_EMAIL" >> "$GITHUB_STEP_SUMMARY"'),
    hardening: (d) => (d.concurrency['cancel-in-progress'] = true),
    pinnedActions: (d) => (d.jobs.run.steps[0].uses = 'actions/checkout@v4'),
  };
  for (const [name, mutate] of Object.entries(unsafe)) {
    it(`${name} reports an unsafe copy`, () => {
      const doc = clone();
      mutate(doc);
      assert.notDeepEqual(rules[name](doc, raw), []);
    });
  }

  it('noInputsInScripts reports the bracket form', () => {
    const doc = clone();
    doc.jobs.run.steps[2].run = 'echo "${{ inputs[\'max_per_run\'] }}"';
    assert.notDeepEqual(rules.noInputsInScripts(doc), []);
  });
  it('requestEmailStaysPrivate reports shell tracing', () => {
    const doc = clone();
    doc.jobs.run.steps[2].run = `set -x\n${doc.jobs.run.steps[2].run}`;
    assert.notDeepEqual(rules.requestEmailStaysPrivate(doc, raw), []);
  });
  it('pinnedActions reports a missing version comment', () => {
    assert.notDeepEqual(rules.pinnedActions(real, raw.replace(/ # v4\.4\.0/, '')), []);
  });
  it('requestEmailStaysPrivate reports a second use of the input', () => {
    assert.notDeepEqual(rules.requestEmailStaysPrivate(real, `${raw}\n# ${'$'}{{ inputs.request_email }}`), []);
  });
});
