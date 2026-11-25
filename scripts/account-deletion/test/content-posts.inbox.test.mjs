import test from 'node:test';
import assert from 'node:assert/strict';
import { addPending, markPosted, fillSummaries, getStatus, pullApprovedPosts, markImported } from '../../content-posts/inbox.mjs';

const item = (o = {}) => ({
  id: 'rule-of-72', type: 'telegram-post', status: 'approved', title: 'T', version: 3,
  updatedAt: '2026-11-15T20:00:00.000Z', data: { app: 'InvTrack', body: 'B' }, ...o,
});
const fakeInbox = (items, calls = []) => async (url, init) => {
  const body = JSON.parse(init.body);
  calls.push(body);
  const out = body.action === 'list' ? { ok: true, items } : { ok: true, item: {} };
  return { ok: true, json: async () => out };
};
const opts = (fetchFn) => ({ url: 'https://x/exec', token: 'secret-tok', fetchFn });

test('approved InvTrack posts become importable posts', async () => {
  const calls = [];
  const posts = await pullApprovedPosts(opts(fakeInbox([item()], calls)));
  assert.deepEqual(posts, [{ id: 'rule-of-72', title: 'T', body: 'B', approvedAt: '2026-11-15', version: 3 }]);
  assert.equal(calls[0].type, 'telegram-post');
  assert.equal(calls[0].status, 'approved');
});

test('items from other apps or without a body are skipped', async () => {
  const posts = await pullApprovedPosts(opts(fakeInbox([
    item({ id: 'a', data: { app: 'Studio', body: 'x' } }),
    item({ id: 'b', data: { app: 'InvTrack' } }),
  ])));
  assert.deepEqual(posts, []);
});

test('markImported moves the item on with a stale-write check', async () => {
  const calls = [];
  await markImported('rule-of-72', 3, opts(fakeInbox([], calls)));
  assert.deepEqual(calls[0], { action: 'update', token: 'secret-tok', id: 'rule-of-72', ifVersion: 3, set: { status: 'scheduled' } });
});

test('an inbox error gives a short code, never the token', async () => {
  const f = async () => ({ ok: true, json: async () => ({ ok: false, error: { code: 'unauthorized', message: 'secret-tok revoked' } }) });
  await assert.rejects(pullApprovedPosts(opts(f)), (e) => {
    assert.equal(e.code, 'inbox-unauthorized');
    assert.ok(!`${e.message}${e.code}`.includes('secret-tok'));
    return true;
  });
});

test('every inbox request has a deadline', async () => {
  let signal;
  await pullApprovedPosts(opts(async (url, init) => { signal = init.signal; return { ok: true, json: async () => ({ ok: true, items: [] }) }; }));
  assert.ok(signal instanceof AbortSignal);
});

test('addPending adds a waiting item labelled as InvTrack', async () => {
  const calls = [];
  await addPending({ id: 'inbox-test', type: 'decision', title: 'Inbox test: tap Approve', summary: 'S', data: { body: 'B' } }, opts(fakeInbox([], calls)));
  assert.deepEqual(calls[0], {
    action: 'add', token: 'secret-tok', id: 'inbox-test', type: 'decision', status: 'pending',
    title: 'Inbox test: tap Approve', summary: 'S', data: { body: 'B', app: 'InvTrack', icon: '📈' },
  });
});

test('addPending needs an id and a title', async () => {
  await assert.rejects(addPending({ title: 'T' }, opts(fakeInbox([]))), /id and title/);
  await assert.rejects(addPending({ id: 'x' }, opts(fakeInbox([]))), /id and title/);
});

test('getStatus reads one item back and returns only its status', async () => {
  const calls = [];
  const f = async (url, init) => { calls.push(JSON.parse(init.body)); return { ok: true, json: async () => ({ ok: true, item: { id: 'x', status: 'approved', title: 'secret title' } }) }; };
  assert.equal(await getStatus('x', opts(f)), 'approved');
  assert.deepEqual(calls[0], { action: 'get', id: 'x', token: 'secret-tok' });
});

test('fillSummaries copies the post text into summary for InvTrack posts that have none', async () => {
  const calls = [];
  const items = [
    item({ id: 'a', version: 2, data: { app: 'InvTrack', body: 'AAA' } }),
    item({ id: 'b', summary: 'already', data: { app: 'InvTrack', body: 'BBB' } }),
    item({ id: 'c', data: { app: 'Studio', body: 'CCC' } }),
  ];
  const n = await fillSummaries(opts(fakeInbox(items, calls)));
  assert.equal(n, 1);
  assert.deepEqual(calls.filter((c) => c.action === 'update'), [{ action: 'update', id: 'a', ifVersion: 2, set: { summary: 'AAA' }, token: 'secret-tok' }]);
  assert.equal(calls[0].type, 'telegram-post');
  assert.equal('status' in calls[0], false);
});

test('markPosted records where and when a post went out, keeping the rest of the item data', async () => {
  const calls = [];
  const f = async (url, init) => {
    const b = JSON.parse(init.body); calls.push(b);
    const out = b.action === 'get' ? { ok: true, item: { id: 'x', version: 4, status: 'scheduled', data: { app: 'InvTrack', icon: '📈', body: 'B' } } } : { ok: true, item: {} };
    return { ok: true, json: async () => out };
  };
  await markPosted('x', { url: 'https://t.me/c/9', at: '2026-11-17T03:31:00.000Z' }, opts(f));
  assert.deepEqual(calls[1], {
    action: 'update', id: 'x', ifVersion: 4, token: 'secret-tok',
    set: { status: 'posted', data: { app: 'InvTrack', icon: '📈', body: 'B', posted: { telegram: 'https://t.me/c/9' }, postedAt: '2026-11-17T03:31:00.000Z' } },
  });
});

test('markPosted adds the post as already posted when the inbox has never seen it', async () => {
  const calls = [];
  const f = async (url, init) => {
    const b = JSON.parse(init.body); calls.push(b);
    const out = b.action === 'get' ? { ok: false, error: { code: 'not_found', message: 'no item' } } : { ok: true, item: {} };
    return { ok: true, json: async () => out };
  };
  await markPosted('file-post', { url: 'https://t.me/c/9', at: '2026-11-25T13:24:00.000Z', title: 'T', body: 'Body text' }, opts(f));
  assert.deepEqual(calls[1], {
    action: 'add', token: 'secret-tok', id: 'file-post', type: 'telegram-post', status: 'posted', title: 'T', summary: 'Body text',
    data: { app: 'InvTrack', icon: '📈', body: 'Body text', posted: { telegram: 'https://t.me/c/9' }, postedAt: '2026-11-25T13:24:00.000Z' },
  });
});

test('markPosted still fails on other inbox errors, and without a title there is nothing to add', async () => {
  const f = (code) => async () => ({ ok: true, json: async () => ({ ok: false, error: { code, message: 'x' } }) });
  await assert.rejects(markPosted('x', { url: 'https://t.me/c/9', at: 'now', title: 'T', body: 'B' }, opts(f('unauthorized'))), { code: 'inbox-unauthorized' });
  await assert.rejects(markPosted('x', { url: 'https://t.me/c/9', at: 'now' }, opts(f('not_found'))), { code: 'inbox-not_found' });
});
