// This job's logs and step summary are public, and an error message can carry a uid, an email or a document path.
// An error is recorded as a short code only, never as its message. ga4.mjs applies the same rule to its own errors.

const SAFE_CODE = /^[A-Za-z0-9_./-]{1,40}$/;

/** e.code when it is a short code (letters, digits and _ . / -; a whole-number gRPC code counts), else the word 'error'. Never reads e.message. */
export function safeErrorCode(e) {
  const code = Number.isInteger(e?.code) ? String(e.code) : e?.code;
  return typeof code === 'string' && SAFE_CODE.test(code) ? code : 'error';
}
