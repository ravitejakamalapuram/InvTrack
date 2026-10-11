// The job's logs and step summary are public, so an error may be recorded as a short code only. Needs no emulator.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { safeErrorCode } from '../safe-error.mjs';

const UID = 'leakcanary7Zq2';

describe('safeErrorCode', () => {
  it('keeps a short code', () => {
    for (const code of ['auth/user-not-found', 'auth/internal-error', 'permission-denied', 'ECONNRESET', 'a.b_c-d/e']) {
      assert.equal(safeErrorCode(Object.assign(new Error('x'), { code })), code);
    }
  });

  it('keeps a numeric gRPC code as text', () => {
    assert.equal(safeErrorCode(Object.assign(new Error('x'), { code: 14 })), '14');
  });

  it('never uses the message: a codeless error that holds the uid is just "error"', () => {
    const e = new Error(`Failed to delete ${UID}`);
    assert.equal(safeErrorCode(e), 'error');
    assert.ok(!safeErrorCode(e).includes(UID));
  });

  it('accepts 40 characters and refuses 41', () => {
    assert.equal(safeErrorCode({ code: 'a'.repeat(40) }), 'a'.repeat(40));
    assert.equal(safeErrorCode({ code: 'a'.repeat(41) }), 'error');
  });

  it('refuses a code outside the allowed characters, even when it holds a uid', () => {
    for (const code of ['', 'two words', 'line\nbreak', 'a%0Ab', 'a:b', 'a,b', 'a@b.com', `${UID} failed`, `${UID}\n`]) {
      assert.equal(safeErrorCode({ code }), 'error', JSON.stringify(code));
    }
  });

  it('turns anything that is not an error with a usable code into "error"', () => {
    for (const thrown of [undefined, null, UID, 42, {}, { code: null }, { code: {} }, { code: [UID] }, { code: true }, { message: UID }]) {
      assert.equal(safeErrorCode(thrown), 'error', JSON.stringify(thrown));
    }
  });
});
