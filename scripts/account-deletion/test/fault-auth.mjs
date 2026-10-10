// Preloaded into run.mjs by the job tests (node --import). It makes one Admin Auth call fail with a codeless error whose
// message holds the uid, the way a library error can. It lives in test/ and the job never loads it.
import { Auth } from 'firebase-admin/auth';

const method = process.env.FAULT_AUTH_METHOD;
if (method !== 'deleteUser' && method !== 'getUser') throw new Error('FAULT_AUTH_METHOD must be deleteUser or getUser');

Auth.prototype[method] = async function fail(uid) {
  throw new Error(`${method} failed for ${uid}`);
};
