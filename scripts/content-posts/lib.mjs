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

/** Takes the post for this run and returns its attempt number, or 0 if another run has it, it is done, or it has failed too often. */
function claim(db, ref, now) {
  return db.runTransaction(async (tx) => {
    const cur = (await tx.get(ref)).data();
    if (cur && cur.status !== 'failed') return 0; // posted, or another run is sending it
    const attempts = (cur?.attempts ?? 0) + 1;
    if (attempts > MAX_ATTEMPTS) return 0;
    tx.set(ref, { status: 'sending', startedAt: now, attempts });
    return attempts;
  });
}

/**
 * Sends the oldest approved post that has no delivery on this channel yet, then records it.
 * The post is claimed ("sending") before it is sent, so two overlapping runs cannot both send it, and a
 * crash after sending can never cause a repeat: a stuck "sending" record is left for a person to look at.
 * A failed attempt is recorded with a short code only; the post is retried on later runs, up to
 * MAX_ATTEMPTS, so one bad post cannot block the newer ones.
 * `skipIfPostedSince` (a Date) makes the run a no-op when a post already went out since then (one tip a day).
 */
export async function postNextToTelegram({ db, send, now = new Date(), dryRun = false, channel = 'telegram', skipIfPostedSince = null }) {
  const snap = await db.collection('contentPosts').where('status', '==', 'approved').get();
  const posts = snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((p) => {
      // A hand-edited post without a valid approval date must not break the sort and block every later run.
      if (typeof p.approvedAt?.toMillis === 'function') return true;
      console.warn(`Skipping post ${p.id}: missing or invalid approvedAt.`);
      return false;
    })
    .sort((a, b) => a.approvedAt.toMillis() - b.approvedAt.toMillis() || a.id.localeCompare(b.id));

  // GitHub can start a scheduled run hours late, or two close together. With a cutoff, a post that already went
  // out since then means today's tip is done, so this run does nothing.
  if (skipIfPostedSince) {
    const deliveries = await Promise.all(posts.map((p) => db.doc(`contentPosts/${p.id}/deliveries/${channel}`).get()));
    const done = deliveries.some((d) => d.data()?.status === 'posted' && d.data().postedAt?.toMillis?.() >= skipIfPostedSince.getTime());
    if (done) return { postId: null, skipped: true };
  }

  for (const post of posts) {
    const ref = db.doc(`contentPosts/${post.id}/deliveries/${channel}`);
    if (dryRun) {
      const cur = (await ref.get()).data();
      if (cur && cur.status !== 'failed') continue;
      if ((cur?.attempts ?? 0) >= MAX_ATTEMPTS) continue;
      return { postId: post.id, dryRun: true };
    }
    const attempt = await claim(db, ref, now);
    if (!attempt) continue;

    let messageId;
    try {
      messageId = await send(post);
    } catch (e) {
      const code = SAFE_CODE.test(e?.code ?? '') ? e.code : 'send-failed';
      // Only a clear rejection by Telegram (HTTP 4xx, including 429) is safe to retry. Anything else, such as a
      // dropped connection or an unreadable reply, may have delivered the post, so the record stays "sending"
      // for a person to check the channel before any resend.
      if (/^telegram-http-4\d\d$/.test(code)) {
        try {
          // A bad token, bot or chat (401/403/404) says nothing about this post, so it does not use up an attempt.
          const configError = /^telegram-http-(401|403|404)$/.test(code);
          await ref.update({ status: 'failed', failedAt: now, error: code, attempts: configError ? attempt - 1 : attempt });
        } catch {
          // The record stays "sending"; the original code below is still reported.
        }
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
