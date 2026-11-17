// Command line for the shared content list.
//
//   node run.mjs import posts.json        add approved posts to Firestore (a JSON array: id, title, body, approvedAt)
//   node run.mjs inbox-test               send one test item to the shared inbox (needs INBOX_URL and INBOX_TOKEN)
//   node run.mjs import-inbox             add posts approved in the shared inbox (needs INBOX_URL and INBOX_TOKEN), skipping existing ones
//   node run.mjs post [--dry-run]         send the next approved post to Telegram and record it
//   node run.mjs import posts.json --create-only   same, but skip posts that already exist
//                  [--once-per-day]     do nothing if a post already went out today (India time)
//
// Posting needs TELEGRAM_BOT_TOKEN and TELEGRAM_CHANNEL_ID. Firestore access comes from the environment's
// Google login (the content-posting service account in CI). Errors print a short code only: Telegram URLs
// hold the bot token.
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { importPosts, postNextToTelegram } from './lib.mjs';
import { addPending, markPosted, fillSummaries, getStatus, markImported, pullApprovedPosts } from './inbox.mjs';
import { formatPost } from '../telegram-tip/post-tip.mjs';

// firebase-admin is installed under scripts/account-deletion (one lockfile for the repo's jobs).
const require = createRequire(new URL('../account-deletion/package.json', import.meta.url));

export async function sendToTelegram(post, { token, chat, fetchFn = fetch }) {
  const res = await fetchFn(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ chat_id: chat, text: formatPost(post) }),
  });
  if (!res.ok) throw Object.assign(new Error('telegram'), { code: `telegram-http-${res.status}` });
  const json = await res.json();
  if (!json?.ok || !json.result?.message_id) throw Object.assign(new Error('telegram'), { code: 'telegram-bad-reply' });
  return json.result.message_id;
}

/** Midnight at the start of the current day in India (UTC+5:30), as a Date. */
export function startOfIndiaDay(now) {
  const offset = 5.5 * 3600 * 1000;
  return new Date(Math.floor((now.getTime() + offset) / 86400000) * 86400000 - offset);
}

const TELEGRAM_CHANNEL_URL = 'https://t.me/invtrack_tips';

async function main() {
  const [cmd, arg] = process.argv.slice(2);
  if (cmd === 'inbox-fill-summaries') {
    const opts = { url: process.env.INBOX_URL, token: process.env.INBOX_TOKEN };
    if (!opts.url || !opts.token) throw new Error('inbox-fill-summaries needs INBOX_URL and INBOX_TOKEN');
    console.log(`Filled the summary of ${await fillSummaries(opts)} post(s).`);
    return;
  }
  if (cmd === 'inbox-test') {
    // Needs no database. Sends one harmless item so the owner can see it in Telegram and on the dashboard.
    const opts = { url: process.env.INBOX_URL, token: process.env.INBOX_TOKEN };
    if (!opts.url || !opts.token) throw new Error('inbox-test needs INBOX_URL and INBOX_TOKEN');
    const id = `inbox-test-${new Date().toISOString().slice(0, 10)}`;
    if (arg === 'check') { console.log(`Test item status: ${await getStatus(id, opts)}`); return; }
    await addPending({ id, type: 'decision',
      title: 'Inbox test: tap Approve', summary: 'Checks that InvTrack can reach your inbox. Nothing happens when you tap.' }, opts);
    console.log('Test item sent to the inbox.');
    return;
  }
  const { applicationDefault, initializeApp } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  initializeApp({ credential: applicationDefault(), projectId: process.env.GCLOUD_PROJECT || 'invtracker-b19d1' });
  const db = getFirestore();

  if (cmd === 'import') {
    const posts = JSON.parse(readFileSync(arg, 'utf8'));
    await importPosts(db, posts, { createOnly: process.argv.includes('--create-only') });
    console.log(`Imported ${posts.length} post(s).`);
  } else if (cmd === 'import-inbox') {
    const o = { url: process.env.INBOX_URL, token: process.env.INBOX_TOKEN };
    if (!o.url || !o.token) throw new Error('INBOX_URL and INBOX_TOKEN must be set');
    const posts = await pullApprovedPosts(o);
    if (posts.length) await importPosts(db, posts.map(({ version, ...p }) => p), { createOnly: true });
    for (const p of posts) await markImported(p.id, p.version, o);
    console.log(`Imported ${posts.length} post(s) from the inbox.`);
  } else if (cmd === 'post') {
    const dryRun = process.argv.includes('--dry-run');
    const token = process.env.TELEGRAM_BOT_TOKEN;
    const chat = process.env.TELEGRAM_CHANNEL_ID;
    if (!dryRun && (!token || !chat)) throw new Error('TELEGRAM_BOT_TOKEN and TELEGRAM_CHANNEL_ID must be set');
    const skipIfPostedSince = process.argv.includes('--once-per-day') ? startOfIndiaDay(new Date()) : null;
    const r = await postNextToTelegram({ db, dryRun, skipIfPostedSince, send: (p) => sendToTelegram(p, { token, chat }) });
    if (r.skipped) {
      console.log('A post already went out today. Nothing to do.');
    } else if (!r.postId) {
      // An empty queue on a live run must be noticed, or the channel goes quiet without any failure.
      if (!dryRun) throw new Error('No approved post is waiting to be sent. Import more posts.');
      console.log('Nothing to post.');
    } else {
      console.log(`${dryRun ? 'Would post' : 'Posted'} ${r.postId}.`);
      if (!dryRun && process.env.INBOX_URL && process.env.INBOX_TOKEN) {
        // The post is out. Telling the inbox is for its Pipeline page only, so a failure here is a warning.
        try {
          await markPosted(r.postId, { url: `${TELEGRAM_CHANNEL_URL}/${r.messageId}`, at: new Date().toISOString() },
            { url: process.env.INBOX_URL, token: process.env.INBOX_TOKEN });
        } catch (e) {
          console.log(`::warning::inbox not updated (${e.code ?? 'error'})`);
        }
      }
    }
  } else {
    throw new Error('usage: run.mjs import <posts.json> | import-inbox | post [--dry-run]');
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().then(
    () => process.exit(0),
    (e) => {
      console.error(e.message);
      process.exit(1);
    },
  );
}
