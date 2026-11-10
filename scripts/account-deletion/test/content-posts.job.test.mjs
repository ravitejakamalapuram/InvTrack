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
  it('posts the oldest approved post with no Telegram delivery and records it', async () => {
    await importPosts(db, [post('b', '2026-11-12'), post('a', '2026-11-11')]);
    const sent = [];
    const r = await postNextToTelegram({ db, now: T0, send: async (p) => { sent.push(p.id); return '777'; } });
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

  it('dry run picks the post but sends and writes nothing', async () => {
    await importPosts(db, [post('a', '2026-11-11')]);
    const r = await postNextToTelegram({ db, now: T0, dryRun: true, send: async () => assert.fail('sent') });
    assert.equal(r.postId, 'a');
    assert.equal((await db.doc('contentPosts/a/deliveries/telegram').get()).exists, false);
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

