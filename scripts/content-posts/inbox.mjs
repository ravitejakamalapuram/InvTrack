// Reads approved Telegram posts from the shared approval inbox (github.com/ravitejakamalapuram/inbox).
// InvTrack adds each draft as an item: type "telegram-post", title, and data {app: "InvTrack", icon, body, image?}.
// The owner approves it in Telegram or on the dashboard. This file only reads the approved ones and moves
// them on. Errors carry a short code only: the token must never reach a log.

export const POST_TYPE = 'telegram-post';
export const APP = 'InvTrack';

// The deadline covers the reply body too, so a stalled inbox cannot eat the job's time for the daily post.
async function call(body, { url, token, fetchFn = fetch, timeoutMs = 20000 }) {
  const res = await fetchFn(url, { method: 'POST', redirect: 'follow', body: JSON.stringify({ ...body, token }), signal: AbortSignal.timeout(timeoutMs) });
  const json = await res.json();
  if (!json?.ok) throw Object.assign(new Error('inbox'), { code: `inbox-${json?.error?.code ?? 'bad-reply'}` });
  return json;
}

/** Approved InvTrack posts, in the shape `importPosts` takes (plus the item version for `markImported`). */
export async function pullApprovedPosts(opts) {
  const { items = [] } = await call({ action: 'list', type: POST_TYPE, status: 'approved', order: 'oldest' }, opts);
  return items
    .filter((i) => i.data?.app === APP && i.title?.trim() && i.data?.body?.trim())
    .map((i) => ({
      id: i.id, title: i.title, body: i.data.body,
      ...(i.data.image ? { image: i.data.image } : {}),
      approvedAt: String(i.updatedAt).slice(0, 10), version: i.version,
    }));
}

/** Takes an imported post out of "waiting for me" so it is not imported twice. */
export function markImported(id, version, opts) {
  return call({ action: 'update', id, ifVersion: version, set: { status: 'scheduled' } }, opts);
}
