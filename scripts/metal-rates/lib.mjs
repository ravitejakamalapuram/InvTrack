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

// Rupees per gram over dollars per gram: today about 109 (gold) and 112 (silver).
const CROSS_CHECK = [70, 150];

const inRange = (n, [lo, hi]) => typeof n === 'number' && Number.isFinite(n) && n >= lo && n <= hi;

/**
 * The provider's own time. It must be readable and not in the future (beyond 5 minutes of clock drift): a feed with
 * no usable time is refused, so a frozen feed cannot look fresh every day.
 */
function readTime(value, now) {
  const t = typeof value === 'string' ? new Date(value) : null;
  if (!t || Number.isNaN(t.getTime())) throw new Error('no readable time');
  if (t.getTime() > now.getTime() + 5 * 60_000) throw new Error('time is in the future');
  return t;
}

async function getJson(fetchFn, url) {
  const res = await fetchFn(url, {
    headers: { 'User-Agent': 'InvTrack-metal-rates/1.0 (GitHub Actions)', Accept: 'application/json' },
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  try {
    return await res.json();
  } catch {
    // A fixed reason: a piece of the reply must never reach the log.
    throw new Error('reply is not JSON');
  }
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

/** A short reason with no control characters, so nothing a server sent can start a workflow command. */
function safeReason(e) {
  const text = e instanceof Error ? e.message : 'failed';
  return text.replace(/[^\x20-\x7e]/g, ' ').slice(0, 120);
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
        errors.push(`${label}: ${safeReason(e)}`);
      }
    }),
  );
  // The two sources must roughly agree: India sell price over the dollar price is about 109 for gold and about
  // 112 for silver (the dollar rate, plus duty, GST and the local premium). Far outside that band one of them is
  // wrong, and the India figure, which comes from the smaller source, is the one dropped.
  if (result.inr && result.usd) {
    for (const metal of ['gold', 'silver']) {
      const ratio = result.inr[metal] / result.usd[metal];
      if (!(ratio >= CROSS_CHECK[0] && ratio <= CROSS_CHECK[1])) {
        delete result.inr;
        errors.push(`India selling rate: disagrees with the international rate (${metal})`);
        break;
      }
    }
  }
  return result;
}

/** The fields to merge into `metalRates/latest`: only the sides that were read. Null when there is nothing. */
export function buildUpdate(result) {
  const update = {};
  if (result.inr) update.inr = result.inr;
  if (result.usd) update.usd = result.usd;
  return Object.keys(update).length ? update : null;
}
