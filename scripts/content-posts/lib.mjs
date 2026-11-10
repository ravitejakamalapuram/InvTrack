// Logic for the shared content list: `contentPosts/{id}` (title, body, status, approvedAt, optional image)
// with one delivery record per channel at `contentPosts/{id}/deliveries/{channel}`.
// The database is passed in, so tests use the emulator and the jobs use the Admin SDK.

const SAFE_CODE = /^[a-z0-9-]{1,40}$/;
const DAY_ISO = /^\d{4}-\d{2}-\d{2}$/;
export const MAX_ATTEMPTS = 3;

/**
 * Adds approved posts, or updates their text. A post that already exists keeps its status (so a post
 * withdrawn later is not approved again by a re-import) and its other fields. Delivery records are never
 * touched. All posts are written in one batch: either every post is imported or none.
 */
export async function importPosts(db, posts) {
  const prepared = posts.map((p) => {
    if (!p.id || !p.title?.trim() || !p.body?.trim()) throw new Error(`post ${p.id ?? '?'}: id, title and body are required`);
    if (!DAY_ISO.test(p.approvedAt ?? '') || Number.isNaN(Date.parse(`${p.approvedAt}T00:00:00Z`))) {
      throw new Error(`post ${p.id}: approvedAt must be YYYY-MM-DD`);
    }
    const data = { title: p.title, body: p.body, approvedAt: new Date(`${p.approvedAt}T00:00:00Z`) };
    if (p.image) data.image = p.image;
    return { ref: db.doc(`contentPosts/${p.id}`), data };
  });
  const existing = await Promise.all(prepared.map((x) => x.ref.get()));
  const batch = db.batch();
  prepared.forEach((x, i) => {
    batch.set(x.ref, existing[i].exists ? x.data : { ...x.data, status: 'approved' }, { merge: true });
  });
  await batch.commit();
}

/** Takes the post for this run, or returns false if another run has it, it is done, or it has failed too often. */
function claim(db, ref, now) {
  return db.runTransaction(async (tx) => {
    const cur = (await tx.get(ref)).data();
    if (cur && cur.status !== 'failed') return false; // posted, or another run is sending it
    const attempts = (cur?.attempts ?? 0) + 1;
    if (attempts > MAX_ATTEMPTS) return false;
    tx.set(ref, { status: 'sending', startedAt: now, attempts });
    return true;
  });
}

/**
 * Sends the oldest approved post that has no delivery on this channel yet, then records it.
 * The post is claimed ("sending") before it is sent, so two overlapping runs cannot both send it, and a
 * crash after sending can never cause a repeat: a stuck "sending" record is left for a person to look at.
 * A failed attempt is recorded with a short code only; the post is retried on later runs, up to
 * MAX_ATTEMPTS, so one bad post cannot block the newer ones.
 */
export async function postNextToTelegram({ db, send, now = new Date(), dryRun = false, channel = 'telegram' }) {
  const snap = await db.collection('contentPosts').where('status', '==', 'approved').get();
  const posts = snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .sort((a, b) => a.approvedAt.toMillis() - b.approvedAt.toMillis() || a.id.localeCompare(b.id));

  for (const post of posts) {
    const ref = db.doc(`contentPosts/${post.id}/deliveries/${channel}`);
    if (dryRun) {
      const cur = (await ref.get()).data();
      if (cur && cur.status !== 'failed') continue;
      if ((cur?.attempts ?? 0) >= MAX_ATTEMPTS) continue;
      return { postId: post.id, dryRun: true };
    }
    if (!(await claim(db, ref, now))) continue;

    let messageId;
    try {
      messageId = await send(post);
    } catch (e) {
      const code = SAFE_CODE.test(e?.code ?? '') ? e.code : 'send-failed';
      try {
        await ref.update({ status: 'failed', failedAt: now, error: code });
      } catch {
        // The record stays "sending"; the original code below is still reported.
      }
      throw new Error(code);
    }
    await recordPosted(ref, now, messageId);
    return { postId: post.id };
  }
  return { postId: null };
}

/** The message is already on Telegram, so retry the write a few times before giving up loudly. */
async function recordPosted(ref, now, messageId) {
  for (let i = 0; i < 3; i++) {
    try {
      await ref.update({ status: 'posted', postedAt: now, externalMessageId: String(messageId) });
      if ((await ref.get()).data()?.status === 'posted') return;
    } catch {
      // try again
    }
  }
  throw new Error('delivery-not-recorded');
}
