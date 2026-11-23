// The daily metal rates job: reads the India selling rate and the international rate, checks them, and builds the
// document the app reads. No network: the fetch is passed in.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { TROY_OUNCE_GRAMS, fetchRates, buildUpdate } from '../../metal-rates/lib.mjs';

const NOW = new Date('2026-11-23T05:00:00Z');

const oro = (over = {}) => ({
  statusCode: 200,
  data: {
    gold: { buy: 13074.89, sell: 12633.66, currency: 'INR', unit: 'gram' },
    silver: { buy: 160.45, sell: 150.98, currency: 'INR', unit: 'gram' },
    timestamp: '2026-11-23T04:52:29.914Z',
    ...over,
  },
});
const goldApi = (price, at = '2026-11-23T04:48:41Z') => ({ currency: 'USD', price, updatedAt: at });

/** A fake fetch: url fragment -> JSON body (or an Error / a status). */
function fakeFetch(routes) {
  return async (url) => {
    const hit = Object.entries(routes).find(([k]) => url.includes(k));
    if (!hit) throw new Error(`unexpected url ${url}`);
    const v = hit[1];
    if (v instanceof Error) throw v;
    if (typeof v === 'number') return { ok: false, status: v, json: async () => ({}) };
    return { ok: true, status: 200, json: async () => v };
  };
}

const good = {
  'oropocket.com': oro(),
  '/XAU': goldApi(3610.949951),
  '/XAG': goldApi(42.103001),
};

describe('fetchRates', () => {
  it('uses the India selling rate, not the buy rate', async () => {
    const r = await fetchRates(fakeFetch(good), NOW);
    assert.equal(r.inr.gold, 12633.66);
    assert.equal(r.inr.silver, 150.98);
    assert.equal(r.inr.updatedAt.toISOString(), '2026-11-23T04:52:29.914Z');
  });

  it('turns the dollar price per troy ounce into dollars per gram', async () => {
    const r = await fetchRates(fakeFetch(good), NOW);
    assert.equal(TROY_OUNCE_GRAMS, 31.1034768);
    assert.ok(Math.abs(r.usd.gold - 3610.949951 / 31.1034768) < 1e-9);
    assert.ok(Math.abs(r.usd.silver - 42.103001 / 31.1034768) < 1e-9);
    assert.equal(r.usd.updatedAt.toISOString(), '2026-11-23T04:48:41.000Z');
    assert.deepEqual(r.errors, []);
  });

  it('the older of the two metal times is the dollar side time', async () => {
    const r = await fetchRates(
      fakeFetch({ ...good, '/XAG': goldApi(42.1, '2026-11-23T03:00:00Z') }),
      NOW,
    );
    assert.equal(r.usd.updatedAt.toISOString(), '2026-11-23T03:00:00.000Z');
  });

  it('one source failing leaves the other, and says which failed', async () => {
    const r = await fetchRates(fakeFetch({ ...good, 'oropocket.com': 503 }), NOW);
    assert.equal(r.inr, undefined);
    assert.ok(r.usd);
    assert.equal(r.errors.length, 1);
    assert.match(r.errors[0], /india/i);
  });

  it('a network error is an error entry, never a throw', async () => {
    const r = await fetchRates(fakeFetch({ ...good, '/XAU': new Error('socket hang up') }), NOW);
    assert.equal(r.usd, undefined);
    assert.ok(r.inr);
    assert.match(r.errors[0], /international/i);
  });

  const inr = { currency: 'INR', unit: 'gram' };
  for (const [name, body, reason] of [
    ['a zero price', oro({ gold: { sell: 0, ...inr } }), /out of range/],
    ['a missing silver price', oro({ silver: undefined }), /not rupees per gram/],
    ['a text price', oro({ gold: { sell: 'lots', ...inr } }), /out of range/],
    ['a price far outside the plausible range', oro({ gold: { sell: 1.5, ...inr } }), /out of range/],
    ['a price in the wrong currency', oro({ gold: { sell: 12633.66, currency: 'USD', unit: 'gram' } }), /not rupees per gram/],
    ['a price per kilogram', oro({ gold: { sell: 12633.66, currency: 'INR', unit: 'kg' } }), /not rupees per gram/],
  ]) {
    it(`refuses ${name}`, async () => {
      const r = await fetchRates(fakeFetch({ ...good, 'oropocket.com': body }), NOW);
      assert.equal(r.inr, undefined);
      assert.equal(r.errors.length, 1);
      assert.match(r.errors[0], reason, 'must fail on the intended check');
    });
  }

  it('refuses a dollar price that is not dollars', async () => {
    const r = await fetchRates(
      fakeFetch({ ...good, '/XAU': { currency: 'EUR', price: 3000, updatedAt: '2026-11-23T04:48:41Z' } }),
      NOW,
    );
    assert.equal(r.usd, undefined);
  });

  it('a source with no usable time is refused, so a frozen feed cannot look fresh every day', async () => {
    for (const bad of [null, 'soon', '2030-01-01T00:00:00Z']) {
      const india = await fetchRates(fakeFetch({ ...good, 'oropocket.com': oro({ timestamp: bad }) }), NOW);
      assert.equal(india.inr, undefined, `india with ${bad}`);
      assert.ok(india.usd);
      const usd = await fetchRates(fakeFetch({ ...good, '/XAU': goldApi(3610, bad) }), NOW);
      assert.equal(usd.usd, undefined, `usd with ${bad}`);
      assert.ok(usd.inr);
    }
  });

  it('a few minutes of clock drift is allowed', async () => {
    const r = await fetchRates(fakeFetch({ ...good, 'oropocket.com': oro({ timestamp: '2026-11-23T05:03:00Z' }) }), NOW);
    assert.ok(r.inr);
  });

  it('a reply that is not JSON gives a fixed reason, never a piece of the reply', async () => {
    const evil = async () => ({ ok: true, status: 200, json: async () => JSON.parse('::error::pwned\n<html>') });
    const r = await fetchRates(evil, NOW);
    assert.equal(r.inr, undefined);
    assert.equal(r.usd, undefined);
    for (const e of r.errors) assert.doesNotMatch(e, /pwned|html|::/);
  });

  it('drops the India rate when the two sources disagree wildly (one of them is wrong)', async () => {
    const r = await fetchRates(
      fakeFetch({ ...good, 'oropocket.com': oro({ gold: { sell: 5000, currency: 'INR', unit: 'gram' } }) }),
      NOW,
    );
    assert.equal(r.inr, undefined);
    assert.ok(r.usd);
    assert.match(r.errors.join(' '), /disagree/i);
  });
});

describe('buildUpdate', () => {
  it('writes only the sides that were read, so a failed side keeps its last good value', async () => {
    const r = await fetchRates(fakeFetch({ ...good, 'oropocket.com': 503 }), NOW);
    const update = buildUpdate(r);
    assert.deepEqual(Object.keys(update), ['usd']);
    assert.equal(update.usd.updatedAt.toISOString(), '2026-11-23T04:48:41.000Z');
  });

  it('is null when nothing could be read', async () => {
    const r = await fetchRates(fakeFetch({ 'oropocket.com': 503, '/XAU': 503, '/XAG': 503 }), NOW);
    assert.equal(buildUpdate(r), null);
  });
});
