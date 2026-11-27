// findInactiveGuests decides which guest accounts the job deletes once the app's 180-day notice has run out.
// A wrong answer deletes a live guest's data for good, so these tests pin the day boundary, the number that is
// passed in, which timestamp counts as activity, and that an account with a linked provider is never returned.
// They use a fake Auth and need no emulator: `node --test test/sweep.test.mjs`.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { findInactiveGuests } from '../sweep.mjs';

const DAY = 24 * 60 * 60 * 1000;
const NOW = new Date('2026-11-27T00:00:00Z');
// Firebase returns these dates as UTC strings, to the second.
const ago = (days) => new Date(NOW.getTime() - days * DAY).toUTCString();

function user(uid, { providers = [], refreshed = null, signedIn = null, created = ago(1) } = {}) {
  return {
    uid,
    providerData: providers.map((providerId) => ({ providerId })),
    metadata: { lastRefreshTime: refreshed, lastSignInTime: signedIn, creationTime: created },
  };
}

/** `pages` is a list of user lists; the token handed out for page n is `p<n>`, and the last page has none. */
function fakeAuth(pages) {
  const calls = [];
  return {
    calls,
    async listUsers(maxResults, pageToken) {
      calls.push({ maxResults, pageToken });
      const index = pageToken ? Number(pageToken.slice(1)) : 0;
      return { users: pages[index], pageToken: index + 1 < pages.length ? `p${index + 1}` : undefined };
    },
  };
}

const sweep = (users, days = 180) => findInactiveGuests(fakeAuth([users]), NOW, days);

describe('findInactiveGuests: the day boundary', () => {
  it('keeps a guest on day 179 and on day 180, and returns it from day 181', async () => {
    const guests = [
      user('day179', { created: ago(179) }),
      user('day180', { created: ago(180) }),
      user('day181', { created: ago(181) }),
    ];
    assert.deepEqual(await sweep(guests), ['day181']);
  });

  it('uses the number of days it is given', async () => {
    const guests = [user('day100', { created: ago(100) })];
    assert.deepEqual(await sweep(guests, 30), ['day100']);
    assert.deepEqual(await sweep(guests, 180), []);
  });
});

describe('findInactiveGuests: what counts as activity', () => {
  it('keeps an old account that refreshed its sign-in recently', async () => {
    assert.deepEqual(await sweep([user('g', { created: ago(400), signedIn: ago(300), refreshed: ago(5) })]), []);
  });

  it('falls back to the last sign-in when there is no refresh time', async () => {
    assert.deepEqual(await sweep([user('g', { created: ago(400), signedIn: ago(5) })]), []);
    assert.deepEqual(await sweep([user('g', { created: ago(400), signedIn: ago(200) })]), ['g']);
  });

  it('falls back to the creation time when it has neither', async () => {
    assert.deepEqual(await sweep([user('g', { created: ago(200) })]), ['g']);
  });

  it('keeps an account whose dates cannot be read', async () => {
    assert.deepEqual(await sweep([user('g', { created: 'not a date' })]), []);
    assert.deepEqual(await sweep([user('g', { created: undefined })]), []);
  });
});

describe('findInactiveGuests: who is a guest', () => {
  it('never returns an account with a linked sign-in provider, however old', async () => {
    const users = [
      user('google', { providers: ['google.com'], created: ago(1000) }),
      user('guest', { created: ago(1000) }),
    ];
    assert.deepEqual(await sweep(users), ['guest']);
  });

  it('reads every page of users', async () => {
    const auth = fakeAuth([[user('a', { created: ago(5) })], [user('b', { created: ago(500) })], [user('c', { created: ago(500) })]]);
    assert.deepEqual(await findInactiveGuests(auth, NOW, 180), ['b', 'c']);
    assert.deepEqual(
      auth.calls.map((c) => c.pageToken),
      [undefined, 'p1', 'p2'],
    );
  });
});
