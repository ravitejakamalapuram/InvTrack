// Logic for the shared content list: `contentPosts/{id}` (title, body, status, approvedAt, optional image)
// with one delivery record per channel at `contentPosts/{id}/deliveries/{channel}`.
// The database is passed in, so tests use the emulator and the jobs use the Admin SDK.

const SAFE_CODE = /^[a-z0-9-]{1,40}$/;
const DAY_ISO = /^\d{4}-\d{2}-\d{2}$/;

/** Adds or updates approved posts. Never touches delivery records, so re-importing cannot cause a repeat. */
export async function importPosts(db, posts) {
  const docs = posts.map((p) => {
    if (!p.id || !p.title?.trim() || !p.body?.trim()) throw new Error(`post ${p.id ?? '?'}: id, title and body are required`);
    if (!DAY_ISO.test(p.approvedAt ?? '') || Number.isNaN(Date.parse(`${p.approvedAt}T00:00:00Z`))) {
      throw new Error(`post ${p.id}: approvedAt must be YYYY-MM-DD`);
    }
    const data = { title: p.title, body: p.body, status: 'approved', approvedAt: new Date(`${p.approvedAt}T00:00:00Z`) };
    if (p.image) data.image = p.image;
    return [p.id, data];
  });
  for (const [id, data] of docs) await db.doc(`contentPosts/${id}`).set(data);
}

/**
 * Sends the oldest approved post that has no successful delivery on this channel, then records it.
 * A failed attempt is recorded with a short code only, and that post is tried again on the next run.
 */
export async function postNextToTelegram({ db, send, now = new Date(), dryRun = false, channel = 'telegram' }) {
  const snap = await db.collection('contentPosts').where('status', '==', 'approved').get();
  const posts = snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .sort((a, b) => a.approvedAt.toMillis() - b.approvedAt.toMillis() || a.id.localeCompare(b.id));

  for (const post of posts) {
    const ref = db.doc(`contentPosts/${post.id}/deliveries/${channel}`);
    if ((await ref.get()).data()?.status === 'posted') continue;
    if (dryRun) return { postId: post.id, dryRun: true };

    let messageId;
    try {
      messageId = await send(post);
    } catch (e) {
      const code = SAFE_CODE.test(e?.code ?? '') ? e.code : 'send-failed';
      await ref.set({ status: 'failed', failedAt: now, error: code });
      throw new Error(code);
    }
    await ref.set({ status: 'posted', postedAt: now, externalMessageId: String(messageId) });
    if ((await ref.get()).data()?.status !== 'posted') throw new Error('delivery-not-recorded');
    return { postId: post.id };
  }
  return { postId: null };
}
