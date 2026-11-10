// Posts today's tip to the public InvTrack Telegram channel.
//
// The tip comes from assets/tips/tips.json, the same file the app uses, chosen by the date so the
// channel walks through the list in order and starts again at the end.
//
//   node post-tip.mjs --dry-run [--date YYYY-MM-DD]   print the post, send nothing
//   node post-tip.mjs                                  send it (needs TELEGRAM_BOT_TOKEN, TELEGRAM_CHANNEL_ID)
//
// Education only: the post says it is not investment advice, and carries no user data.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const PLAY_URL = 'https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker';
const DAY_MS = 24 * 60 * 60 * 1000;

export function pickTip(tips, dateIso) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateIso)) throw new Error(`bad date: ${dateIso}`);
  if (tips.length === 0) throw new Error('no tips');
  const day = Math.floor(Date.parse(`${dateIso}T00:00:00Z`) / DAY_MS);
  return tips[((day % tips.length) + tips.length) % tips.length];
}

export function formatPost(tip) {
  return [
    `💡 ${tip.title}`,
    '',
    tip.body,
    '',
    'Education, not investment advice.',
    '',
    `Track your FDs, bonds, gold, chits and more in InvTrack: ${PLAY_URL}`,
  ].join('\n');
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const dateArg = args.indexOf('--date');
  const date = dateArg >= 0 ? args[dateArg + 1] : new Date().toISOString().slice(0, 10);

  const here = dirname(fileURLToPath(import.meta.url));
  const tips = JSON.parse(readFileSync(join(here, '../../assets/tips/tips.json'), 'utf8'));
  const text = formatPost(pickTip(tips, date));

  if (dryRun) {
    console.log(text);
    return;
  }
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chat = process.env.TELEGRAM_CHANNEL_ID;
  if (!token || !chat) throw new Error('TELEGRAM_BOT_TOKEN and TELEGRAM_CHANNEL_ID must be set');

  const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ chat_id: chat, text, disable_web_page_preview: false }),
  });
  if (!res.ok) {
    // Never print the response body or URL: the URL holds the token.
    throw new Error(`Telegram answered HTTP ${res.status}`);
  }
  console.log('Posted today\'s tip.');
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
