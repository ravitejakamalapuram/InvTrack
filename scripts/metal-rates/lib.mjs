// Reads today's gold and silver rates and builds the document the app shows on a metal investment's page.
//
// Two independent sources, so one failing never blanks the other:
//   india  - OroPocket's public price endpoint (no key): the rupee SELL rate per gram, what a seller receives.
//            It is a tradeable quote, not a spot benchmark, so the app labels it "selling rate".
//   usd    - gold-api.com (no key): the international price in US dollars per troy ounce, shown per gram.
// Values are checked before they are written; anything odd is left out and reported, and the app keeps showing
// the last good value until it is 3 days old.

export const TROY_OUNCE_GRAMS = 31.1034768;

const INDIA_URL = 'https://api.oropocket.com/public/prices';
const SPOT_URL = (symbol) => `https://api.gold-api.com/price/${symbol}`;

// Plausible bounds per gram. They only catch garbage (a unit mix-up, a zero), not a market move.
const BOUNDS = {
  inr: { gold: [1000, 100000], silver: [10, 2000] },
  usd: { gold: [10, 1000], silver: [0.1, 50] },
};

const inRange = (n, [lo, hi]) => typeof n === 'number' && Number.isFinite(n) && n >= lo && n <= hi;

/** The provider's time if it is readable and not in the future (beyond a minute of clock drift), else `now`. */
function readTime(value, now) {
  const t = typeof value === 'string' ? new Date(value) : null;
  if (!t || Number.isNaN(t.getTime()) || t.getTime() > now.getTime() + 60_000) return now;
  return t;
}

async function getJson(fetchFn, url) {
  const res = await fetchFn(url, {
    headers: { 'User-Agent': 'InvTrack-metal-rates/1.0 (GitHub Actions)', Accept: 'application/json' },
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

async function readIndia(fetchFn, now) {
  const body = await getJson(fetchFn, INDIA_URL);
  const data = body?.data;
  const out = {};
  for (const metal of ['gold', 'silver']) {
    const q = data?.[metal];
    if (q?.currency !== 'INR' || q?.unit !== 'gram') throw new Error(`${metal}: not rupees per gram`);
    if (!inRange(q.sell, BOUNDS.inr[metal])) throw new Error(`${metal}: sell rate out of range`);
    out[metal] = q.sell;
  }
  return { ...out, updatedAt: readTime(data?.timestamp, now) };
}

async function readUsd(fetchFn, now) {
  const out = {};
  let oldest = null;
  for (const [metal, symbol] of [['gold', 'XAU'], ['silver', 'XAG']]) {
    const q = await getJson(fetchFn, SPOT_URL(symbol));
    if (q?.currency !== 'USD') throw new Error(`${metal}: not dollars`);
    const perGram = q.price / TROY_OUNCE_GRAMS;
    if (!inRange(perGram, BOUNDS.usd[metal])) throw new Error(`${metal}: price out of range`);
    out[metal] = perGram;
    const at = readTime(q.updatedAt, now);
    if (!oldest || at < oldest) oldest = at;
  }
  return { ...out, updatedAt: oldest };
}

/**
 * Fetches both sources. Never throws: a source that fails is left out and named in `errors`
 * (a short reason only, never a response body).
 * @returns {{inr?: object, usd?: object, errors: string[]}}
 */
export async function fetchRates(fetchFn, now = new Date()) {
  const errors = [];
  const result = { errors };
  const attempts = [
    ['inr', 'India selling rate', readIndia],
    ['usd', 'International rate', readUsd],
  ];
  await Promise.all(
    attempts.map(async ([key, label, read]) => {
      try {
        result[key] = await read(fetchFn, now);
      } catch (e) {
        errors.push(`${label}: ${e instanceof Error ? e.message : 'failed'}`);
      }
    }),
  );
  return result;
}

/** The fields to merge into `metalRates/latest`: only the sides that were read. Null when there is nothing. */
export function buildUpdate(result) {
  const update = {};
  if (result.inr) update.inr = result.inr;
  if (result.usd) update.usd = result.usd;
  return Object.keys(update).length ? update : null;
}
