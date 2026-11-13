// The content-posts job logic against the Firestore emulator: importing approved posts and picking
// the next one for Telegram. Run: `npm run test:emulator`.
import { beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { db, resetEmulators } from './helpers.mjs';
import { importPosts, postNextToTelegram } from '../../content-posts/lib.mjs';

const T0 = new Date('2026-11-12T03:30:00Z');
const post = (id, approved, extra = {}) => ({
  id,
  title: `Title ${id}`,
  body: `Body ${id}`,
  approvedAt: approved,
  ...extra,
});

beforeEach(resetEmulators);

describe('importPosts', () => {
  it('stores approved posts and does not touch delivery records on a second run', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    await db.doc('contentPosts/a/deliveries/telegram').set({ status: 'posted' });
    await importPosts(db, [post('a', '2026-11-11', { title: 'Edited' })]);
    const doc = (await db.doc('contentPosts/a').get()).data();
    assert.equal(doc.status, 'approved');
    assert.equal(doc.title, 'Edited');
    assert.equal(doc.approvedAt.toDate().toISOString(), '2026-11-11T00:00:00.000Z');
    assert.equal((await db.doc('contentPosts/a/deliveries/telegram').get()).data().status, 'posted');
  });

  it('with createOnly, adds new posts but leaves existing ones exactly as they are', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    await db.doc('contentPosts/a').update({ title: 'Fixed by hand' });
    await importPosts(db, [post('a', '2026-11-11', { title: 'From file' }), post('b', '2026-11-12')], { createOnly: true });
    assert.equal((await db.doc('contentPosts/a').get()).data().title, 'Fixed by hand');
    const b = (await db.doc('contentPosts/b').get()).data();
    assert.equal(b.status, 'approved');
    assert.equal(b.title, 'Title b');
  });

  it('does not re-approve a post that was withdrawn after the first import', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    await db.doc('contentPosts/a').update({ status: 'withdrawn', note: 'kept' });
    await importPosts(db, [post('a', '2026-11-11', { title: 'Edited' })]);
    const doc = (await db.doc('contentPosts/a').get()).data();
    assert.equal(doc.status, 'withdrawn');
    assert.equal(doc.note, 'kept');
    assert.equal(doc.title, 'Edited');
  });

  it('rejects a post without a title, body or valid date', async () => {
    await assert.rejects(importPosts(db, [{ id: 'x', title: 't', body: '' , approvedAt: '2026-11-11' }]));
    await assert.rejects(importPosts(db, [post('y', 'not-a-date')]));
    assert.equal((await db.collection('contentPosts').get()).size, 0);
  });
});

describe('postNextToTelegram', () => {
  it('with a cutoff, does nothing if a post already went out since then', async () => {
    await importPosts(db, [post('a', '2026-11-11'), post('b', '2026-11-12')]);
    await db.doc('contentPosts/a/deliveries/telegram').set({ status: 'posted', postedAt: Timestamp.fromDate(new Date('2026-11-12T03:40:00Z')) });
    const sent = [];
    const r = await postNextToTelegram({ db, now: T0, skipIfPostedSince: new Date('2026-11-11T18:30:00Z'), send: async (p) => { sent.push(p.id); return '1'; } });
    assert.deepEqual(sent, []);
    assert.equal(r.postId, null);
    assert.equal(r.skipped, true);
  });

  it('with a cutoff, a post left "sending" today blocks the next one, but a "failed" one does not', async () => {
    await importPosts(db, [post('a', '2026-11-11'), post('b', '2026-11-12')]);
    const cutoff = new Date('2026-11-11T18:30:00Z');
    await db.doc('contentPosts/a/deliveries/telegram').set({ status: 'sending', startedAt: Timestamp.fromDate(new Date('2026-11-12T03:40:00Z')), attempts: 1 });
    const sent = [];
    const send = async (p) => { sent.push(p.id); return '1'; };
    const blocked = await postNextToTelegram({ db, now: T0, skipIfPostedSince: cutoff, send });
    assert.equal(blocked.skipped, true);
    assert.deepEqual(sent, []);

    await db.doc('contentPosts/a/deliveries/telegram').set({ status: 'failed', failedAt: Timestamp.fromDate(new Date('2026-11-12T03:40:00Z')), attempts: 3, error: 'telegram-http-400' });
    const r = await postNextToTelegram({ db, now: T0, skipIfPostedSince: cutoff, send });
    assert.equal(r.postId, 'b');
    assert.deepEqual(sent, ['b']);
  });

  it('records the time the send finished, so a send that crosses India midnight counts for the new day', async () => {
    await importPosts(db, [post('a', '2026-11-11'), post('b', '2026-11-12')]);
    const started = new Date('2026-11-11T18:29:59Z');
    const finished = new Date('2026-11-11T18:30:05Z');
    await postNextToTelegram({ db, now: started, clock: () => finished, send: async () => '1' });
    assert.equal((await db.doc('contentPosts/a/deliveries/telegram').get()).data().postedAt.toDate().toISOString(), finished.toISOString());
    const sent = [];
    const r = await postNextToTelegram({ db, now: finished, skipIfPostedSince: new Date('2026-11-11T18:30:00Z'), send: async (p) => { sent.push(p.id); return '2'; } });
    assert.equal(r.skipped, true);
    assert.deepEqual(sent, []);
  });

  it('with a cutoff, still posts when the last post was before it', async () => {
    await importPosts(db, [post('a', '2026-11-11'), post('b', '2026-11-12')]);
    await db.doc('contentPosts/a/deliveries/telegram').set({ status: 'posted', postedAt: Timestamp.fromDate(new Date('2026-11-11T09:00:00Z')) });
    const sent = [];
    const r = await postNextToTelegram({ db, now: T0, skipIfPostedSince: new Date('2026-11-11T18:30:00Z'), send: async (p) => { sent.push(p.id); return '1'; } });
    assert.deepEqual(sent, ['b']);
    assert.equal(r.postId, 'b');
  });

  it('posts the oldest approved post with no Telegram delivery and records it', async () => {
    await importPosts(db, [post('b', '2026-11-12'), post('a', '2026-11-11')]);
    const sent = [];
    const r = await postNextToTelegram({ db, now: T0, clock: () => T0, send: async (p) => { sent.push(p.id); return '777'; } });
    assert.deepEqual(sent, ['a']);
    assert.equal(r.postId, 'a');
    const d = (await db.doc('contentPosts/a/deliveries/telegram').get()).data();
    assert.equal(d.status, 'posted');
    assert.equal(d.externalMessageId, '777');
    assert.equal(d.postedAt.toDate().toISOString(), T0.toISOString());
  });

  it('moves on to the next post on the next run and never repeats one', async () => {
    await importPosts(db, [post('a', '2026-11-11'), post('b', '2026-11-12')]);
    const sent = [];
    const send = async (p) => { sent.push(p.id); return '1'; };
    await postNextToTelegram({ db, now: T0, send });
    await postNextToTelegram({ db, now: T0, send });
    const third = await postNextToTelegram({ db, now: T0, send });
    assert.deepEqual(sent, ['a', 'b']);
    assert.equal(third.postId, null);
  });

  it('skips posts that are not approved', async () => {
    await db.doc('contentPosts/draft').set({ title: 't', body: 'b', status: 'draft', approvedAt: Timestamp.fromDate(new Date('2026-11-01')) });
    const r = await postNextToTelegram({ db, now: T0, send: async () => assert.fail('sent a draft') });
    assert.equal(r.postId, null);
  });

  it('records a failure with a short code, no message text, and retries that post next run', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    const boom = async () => { throw Object.assign(new Error('secret-token-in-url'), { code: 'telegram-http-429' }); };
    await assert.rejects(postNextToTelegram({ db, now: T0, send: boom }), /telegram-http-429/);
    const d = (await db.doc('contentPosts/a/deliveries/telegram').get()).data();
    assert.equal(d.status, 'failed');
    assert.equal(d.error, 'telegram-http-429');
    assert.ok(!JSON.stringify(d).includes('secret-token'));
    const r = await postNextToTelegram({ db, now: T0, send: async () => '9' });
    assert.equal(r.postId, 'a');
    assert.equal((await db.doc('contentPosts/a/deliveries/telegram').get()).data().status, 'posted');
  });

  it('keeps the record "sending" after an unclear failure, so the post is never sent twice', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    const dropped = async () => { throw new Error('connection reset'); }; // no code: Telegram may have got it
    await assert.rejects(postNextToTelegram({ db, now: T0, send: dropped }), /send-failed/);
    assert.equal((await db.doc('contentPosts/a/deliveries/telegram').get()).data().status, 'sending');
    const r = await postNextToTelegram({ db, now: T0, send: async () => assert.fail('resent') });
    assert.equal(r.postId, null);
  });

  it('skips an approved post with no valid approvedAt instead of crashing', async () => {
    await db.doc('contentPosts/broken').set({ title: 't', body: 'b', status: 'approved' });
    await importPosts(db, [post('a', '2026-11-11')]);
    const r = await postNextToTelegram({ db, now: T0, send: async () => '1' });
    assert.equal(r.postId, 'a');
  });

  for (const code of ['telegram-http-500', 'telegram-bad-reply']) {
    it(`keeps the record "sending" after ${code}, so the post is never sent twice`, async () => {
      await importPosts(db, [post('a', '2026-11-11')]);
      const bad = async () => { throw Object.assign(new Error('x'), { code }); };
      await assert.rejects(postNextToTelegram({ db, now: T0, send: bad }), new RegExp(code));
      assert.equal((await db.doc('contentPosts/a/deliveries/telegram').get()).data().status, 'sending');
      const r = await postNextToTelegram({ db, now: T0, send: async () => assert.fail('resent') });
      assert.equal(r.postId, null);
    });
  }

  it('does not use up a post\'s attempts when the token or chat is rejected (401/403/404)', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    const badToken = async () => { throw Object.assign(new Error('x'), { code: 'telegram-http-401' }); };
    for (let i = 0; i < 5; i++) await assert.rejects(postNextToTelegram({ db, now: T0, send: badToken }), /telegram-http-401/);
    const r = await postNextToTelegram({ db, now: T0, send: async () => '7' });
    assert.equal(r.postId, 'a');
  });

  it('dry run picks the post but sends and writes nothing', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    const r = await postNextToTelegram({ db, now: T0, dryRun: true, send: async () => assert.fail('sent') });
    assert.equal(r.postId, 'a');
    assert.equal((await db.doc('contentPosts/a/deliveries/telegram').get()).exists, false);
  });

  it('does not resend a post that an earlier run claimed but never recorded', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    await db.doc('contentPosts/a/deliveries/telegram').set({ status: 'sending', attempts: 1 });
    const r = await postNextToTelegram({ db, now: T0, send: async () => assert.fail('resent') });
    assert.equal(r.postId, null);
  });

  it('skips a post that failed three times so newer posts still go out', async () => {
    await importPosts(db, [post('a', '2026-11-11'), post('b', '2026-11-12')]);
    await db.doc('contentPosts/a/deliveries/telegram').set({ status: 'failed', attempts: 3, error: 'telegram-http-400' });
    const r = await postNextToTelegram({ db, now: T0, send: async () => '5' });
    assert.equal(r.postId, 'b');
  });
});

describe('importPosts keeps withdrawn posts withdrawn', () => {
  it('does not re-approve a post that is no longer approved', async () => {
    await db.doc('contentPosts/w').set({ title: 't', body: 'b', status: 'withdrawn', approvedAt: Timestamp.fromDate(new Date('2026-11-01')) });
    await importPosts(db, [post('w', '2026-11-11')]);
    assert.equal((await db.doc('contentPosts/w').get()).data().status, 'withdrawn');
  });
});

describe('postNextToTelegram safety', () => {
  it('never resends a post whose delivery is stuck in "sending"', async () => {
    await importPosts(db, [post('a', '2026-11-11'), post('b', '2026-11-12')]);
    await db.doc('contentPosts/a/deliveries/telegram').set({ status: 'sending' });
    const sent = [];
    await postNextToTelegram({ db, now: T0, send: async (p) => { sent.push(p.id); return '1'; } });
    assert.deepEqual(sent, ['b']);
  });

  it('two overlapping runs send a post only once', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    const sent = [];
    const send = async (p) => { sent.push(p.id); await new Promise((r) => setTimeout(r, 50)); return '1'; };
    await Promise.all([postNextToTelegram({ db, now: T0, send }), postNextToTelegram({ db, now: T0, send })]);
    assert.deepEqual(sent, ['a']);
  });

  it('gives up on a post after 3 failed attempts so newer posts are not blocked', async () => {
    await importPosts(db, [post('a', '2026-11-11'), post('b', '2026-11-12')]);
    const bad = async (p) => { if (p.id === 'a') throw Object.assign(new Error('x'), { code: 'telegram-http-400' }); return '5'; };
    for (let i = 0; i < 3; i++) await assert.rejects(postNextToTelegram({ db, now: T0, send: bad }));
    assert.equal((await db.doc('contentPosts/a/deliveries/telegram').get()).data().attempts, 3);
    const r = await postNextToTelegram({ db, now: T0, send: bad });
    assert.equal(r.postId, 'b');
  });
});

