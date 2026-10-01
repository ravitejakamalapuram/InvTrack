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
 * Firestore data whose Auth user is gone. users/{uid} is never written itself (a "missing
 * ancestor"), so collection('users').get() is empty; listDocuments() does return it.
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

/** Anonymous accounts (no linked provider) with no activity for `days` days. */
export async function findInactiveGuests(auth, now, days) {
  const cutoff = now.getTime() - days * DAY_MS;
  const guests = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const u of page.users) {
      if (u.providerData.length > 0) continue;
      const last = u.metadata.lastRefreshTime ?? u.metadata.lastSignInTime ?? u.metadata.creationTime;
      if (new Date(last).getTime() < cutoff) guests.push(u.uid);
    }
    pageToken = page.pageToken;
  } while (pageToken);
  return guests;
}
