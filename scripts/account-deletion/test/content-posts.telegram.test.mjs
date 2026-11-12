import test from 'node:test';
import assert from 'node:assert/strict';
import { sendToTelegram, startOfIndiaDay } from '../../content-posts/run.mjs';

const post = { title: 'T', body: 'B' };
const reply = (ok, status, json) => async () => ({ ok, status, json: async () => json });

test('sends the formatted post and returns the message id', async () => {
  let sent;
  const id = await sendToTelegram(post, {
    token: 'tok', chat: '@c',
    fetchFn: async (url, init) => { sent = { url, body: JSON.parse(init.body) }; return { ok: true, json: async () => ({ ok: true, result: { message_id: 7 } }) }; },
  });
  assert.equal(id, 7);
  assert.match(sent.body.text, /T\n\nB/);
  assert.equal(sent.body.chat_id, '@c');
});

test('HTTP failure gives a short code, never the token', async () => {
  await assert.rejects(sendToTelegram(post, { token: 'secret-tok', chat: 'c', fetchFn: reply(false, 429, {}) }), (e) => {
    assert.equal(e.code, 'telegram-http-429');
    assert.ok(!`${e.message}${e.code}`.includes('secret-tok'));
    return true;
  });
});

test('a reply without a message id is a failure', async () => {
  await assert.rejects(sendToTelegram(post, { token: 't', chat: 'c', fetchFn: reply(true, 200, { ok: false }) }), { code: 'telegram-bad-reply' });
});

test('the India day starts at 18:30 UTC the evening before', () => {
  assert.equal(startOfIndiaDay(new Date('2026-11-12T03:30:00Z')).toISOString(), '2026-11-11T18:30:00.000Z');
  assert.equal(startOfIndiaDay(new Date('2026-11-11T18:29:59Z')).toISOString(), '2026-11-10T18:30:00.000Z');
  assert.equal(startOfIndiaDay(new Date('2026-11-11T18:30:00Z')).toISOString(), '2026-11-11T18:30:00.000Z');
});
