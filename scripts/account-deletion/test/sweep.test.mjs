// findInactiveGuests decides which guest accounts the job deletes once the app's 180-day notice has run out.
// A wrong answer deletes a live guest's data for good, so these tests pin the day boundary, the number that is
// passed in, which timestamp counts as activity, and that an account with a linked provider is never returned.
// They use a fake Auth and need no emulator: `node --test test/sweep.test.mjs`.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { findInactiveGuests } from '../sweep.mjs';

const DAY = 24 * 60 * 60 * 1000;
const NOW = new Date('2026-11-27T00:00:00Z');
// firebase-admin gives these dates as UTC strings, to the second (or null / 'Invalid Date', see the last group).
const ago = (days) => new Date(NOW.getTime() - days * DAY).toUTCString();
// `days` days and `seconds` seconds before NOW; a negative `seconds` is that much less than `days` days.
const agoBy = (days, seconds) => new Date(NOW.getTime() - days * DAY - seconds * 1000).toUTCString();
// In the future: a device clock set wrong can write a sign-in time ahead of the server's.
const ahead = (days) => ago(-days);

function user(uid, opts = {}) {
  const { providers = [] } = opts;
  // `in`, not a default value: a default would turn an explicit `undefined` into a readable date (or null).
  const get = (key, fallback) => (key in opts ? opts[key] : fallback);
  return {
    uid,
    providerData: providers.map((providerId) => ({ providerId })),
    metadata: {
      lastRefreshTime: get('refreshed', null),
      lastSignInTime: get('signedIn', null),
      creationTime: get('created', ago(1)),
    },
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

  it('keeps a guest at exactly 180 days and one second short of it, and returns it one second past', async () => {
    const guests = [
      user('short', { created: agoBy(180, -1) }),
      user('exact', { created: agoBy(180, 0) }),
      user('past', { created: agoBy(180, 1) }),
    ];
    assert.deepEqual(await sweep(guests), ['past']);
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

  it('uses the newest of the three dates, whatever order they are in', async () => {
    // Refresh older than sign-in is unusual but possible; the newer one is the activity.
    assert.deepEqual(await sweep([user('g', { created: ago(400), refreshed: ago(300), signedIn: ago(5) })]), []);
    assert.deepEqual(await sweep([user('g', { created: ago(400), refreshed: ago(300), signedIn: ago(200) })]), ['g']);
  });
});

// firebase-admin 13.10.0 gives null for a creation or sign-in time it cannot parse (or that is absent), and the literal
// string 'Invalid Date' for a refresh time it cannot parse, so a real record can reach the sweep with null or invalid
// dates. `new Date(null)` is 1 January 1970, which is always older than the cutoff: reading it as a date would delete
// a guest we know nothing about, for good. Doubt keeps the account.
describe('findInactiveGuests: dates that cannot be read', () => {
  const unreadable = [
    ['null', null],
    ['undefined', undefined],
    ['an invalid string', 'not a date'],
    ['an empty string', ''],
    // firebase-admin 13.10.0 gives this literal string for a lastRefreshTime it cannot parse.
    ['the string "Invalid Date"', 'Invalid Date'],
  ];
  for (const [label, value] of unreadable) {
    it(`keeps a guest whose three dates are all ${label}`, async () => {
      const g = user('g', { created: value, signedIn: value, refreshed: value });
      assert.deepEqual(await sweep([g]), []);
    });
  }

  it('keeps the unreadable guest and still returns an old readable one next to it', async () => {
    const users = [
      user('unreadable', { created: null, signedIn: null, refreshed: null }),
      user('old', { created: ago(200) }),
    ];
    assert.deepEqual(await sweep(users), ['old']);
  });

  it('keeps a guest when one date is present but cannot be parsed, even if another is old', async () => {
    assert.deepEqual(await sweep([user('g', { created: ago(400), refreshed: 'not a date' })]), []);
    assert.deepEqual(await sweep([user('g', { created: 'not a date', signedIn: ago(400) })]), []);
    assert.deepEqual(await sweep([user('g', { created: ago(400), refreshed: 'Invalid Date' })]), []);
  });

  it('keeps a guest when a date is an empty string, even if another is old', async () => {
    assert.deepEqual(await sweep([user('g', { created: ago(400), refreshed: '' })]), []);
    assert.deepEqual(await sweep([user('g', { created: ago(400), signedIn: '' })]), []);
    assert.deepEqual(await sweep([user('g', { created: '', signedIn: ago(400) })]), []);
  });

  // A real account always has a creation time. firebase-admin turns an unparseable createdAt into null while
  // lastLoginAt stays readable, so a missing creation time means the record is wrong, not that the guest is idle.
  for (const [label, value] of [['null', null], ['undefined', undefined]]) {
    it(`keeps a guest whose creation time is ${label}, even next to an old valid sign-in or refresh`, async () => {
      assert.deepEqual(await sweep([user('g', { created: value, signedIn: ago(400) })]), []);
      assert.deepEqual(await sweep([user('g', { created: value, refreshed: ago(400) })]), []);
      assert.deepEqual(await sweep([user('g', { created: value, signedIn: ago(400), refreshed: ago(500) })]), []);
    });
  }

  it('keeps a guest whose creation time is "Invalid Date", even next to an old valid sign-in', async () => {
    assert.deepEqual(await sweep([user('g', { created: 'Invalid Date', signedIn: ago(400) })]), []);
  });

  it('does not treat a missing date as unreadable when another date is readable', async () => {
    assert.deepEqual(await sweep([user('g', { created: ago(200), signedIn: null, refreshed: undefined })]), ['g']);
  });
});

describe('findInactiveGuests: dates in the future', () => {
  it('keeps a guest whose newest date is ahead of now, however far ahead', async () => {
    const guests = [
      user('tomorrow', { created: ago(400), signedIn: ahead(1) }),
      user('farAhead', { created: ago(400), signedIn: ahead(400) }),
      user('createdAhead', { created: ahead(400) }),
    ];
    assert.deepEqual(await sweep(guests), []);
  });

  it('still returns an old guest next to one with a future date', async () => {
    const guests = [user('ahead', { created: ahead(400) }), user('old', { created: ago(400) })];
    assert.deepEqual(await sweep(guests), ['old']);
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
