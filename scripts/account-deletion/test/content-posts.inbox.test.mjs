import test from 'node:test';
import assert from 'node:assert/strict';
import { pullApprovedPosts, markImported } from '../../content-posts/inbox.mjs';

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
