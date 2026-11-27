// Finding work: due requests, orphaned Firestore data, inactive guest accounts.

const DAY_MS = 24 * 60 * 60 * 1000;
export const COOLING_MS = DAY_MS;
export const STALE_MS = 3 * DAY_MS;

/** Splits the queue into requests past the 24 h withdrawal window, fresh ones, and malformed ones. */
export async function loadRequests(db, now, coolingMs = COOLING_MS) {
  const due = [];
  const fresh = [];
  const malformed = [];
  const snap = await db.collection('deletionRequests').get();
  for (const doc of snap.docs) {
    const at = doc.get('requestedAt');
    if (typeof at?.toDate !== 'function') {
      malformed.push({ uid: doc.id });
      continue;
    }
    const entry = { uid: doc.id, requestedAt: at.toDate() };
    (now.getTime() - entry.requestedAt.getTime() >= coolingMs ? due : fresh).push(entry);
  }
  return { due, fresh, malformed };
}

/**
 * Firestore data whose Auth user is gone. users/{uid} is usually never written itself (a
 * "missing ancestor"; the app writes only a usdTagRepairResolvedAt field on it), so
 * collection('users').get() misses most users; listDocuments() returns both kinds.
 */
export async function findOrphans(db, auth) {
  const uids = (await db.collection('users').listDocuments()).map((d) => d.id);
  const orphans = [];
  for (let i = 0; i < uids.length; i += 100) {
    const res = await auth.getUsers(uids.slice(i, i + 100).map((uid) => ({ uid })));
    orphans.push(...res.notFound.map((n) => n.uid));
  }
  return orphans;
}

/**
 * Newest of the account's activity times in ms, or null when they cannot be read. firebase-admin 13.10.0 gives a UTC
 * string, null (a time that is absent, or a creation or sign-in time it cannot parse) or the literal 'Invalid Date'
 * (a refresh time it cannot parse). A null is dropped, never read as `new Date(null)`, which is 1970 and would look a
 * half-century idle. The creation time is the exception: a real account always has one, so without it the record is
 * wrong, not idle. A time that is set but is not a date also makes the activity unreadable. Deleting is permanent, so
 * the caller keeps the account on doubt.
 */
function lastActivityMs({ lastRefreshTime, lastSignInTime, creationTime }) {
  if (creationTime == null) return null;
  const times = [lastRefreshTime, lastSignInTime, creationTime]
    .filter((t) => t != null)
    .map((t) => new Date(t).getTime());
  return times.some(Number.isNaN) ? null : Math.max(...times);
}

/** Anonymous accounts (no linked provider) with no activity for `days` days. Unreadable dates keep the account. */
export async function findInactiveGuests(auth, now, days) {
  const cutoff = now.getTime() - days * DAY_MS;
  const guests = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const u of page.users) {
      if (u.providerData.length > 0) continue;
      const last = lastActivityMs(u.metadata);
      if (last !== null && last < cutoff) guests.push(u.uid);
    }
    pageToken = page.pageToken;
  } while (pageToken);
  return guests;
}
