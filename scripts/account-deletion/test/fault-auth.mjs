// Preloaded into run.mjs and verify-run.mjs by the job tests (node --import). It makes one Admin Auth call fail with a
// codeless error whose message holds a uid and an email, the way a library error can. FAULT_AUTH_UID and
// FAULT_AUTH_EMAIL set the planted values; for deleteUser and getUser the uid defaults to the one passed in.
// It lives in test/ and the job never loads it.
import { Auth } from 'firebase-admin/auth';

const METHODS = ['deleteUser', 'getUser', 'getUsers', 'listUsers', 'getUserByEmail'];
const method = process.env.FAULT_AUTH_METHOD;
if (!METHODS.includes(method)) throw new Error(`FAULT_AUTH_METHOD must be one of ${METHODS.join(', ')}`);

Auth.prototype[method] = async function fail(first) {
  const uid = process.env.FAULT_AUTH_UID ?? (typeof first === 'string' ? first : '');
  const email = process.env.FAULT_AUTH_EMAIL ?? '';
  throw new Error(`${method} failed for ${uid} <${email}>`);
};
