// Unit tests for the Google Analytics user-deletion request (A102). No emulator: the HTTP call is injected.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createGa4Deletion, USER_DELETION_SCOPE, USER_DELETION_URL } from '../ga4.mjs';

const recorder = (impl = async () => ({ status: 200 })) => {
  const calls = [];
  const request = async (options) => {
    calls.push(options);
    return impl(options);
  };
  return { calls, request };
};

describe('GA4 User Deletion API request', () => {
  it('pins the endpoint and OAuth scope from Google\'s User Deletion API', () => {
    assert.equal(USER_DELETION_URL, 'https://www.googleapis.com/analytics/v3/userDeletion/userDeletionRequests:upsert');
    assert.equal(USER_DELETION_SCOPE, 'https://www.googleapis.com/auth/analytics.user.deletion');
  });

  it('sends one POST per uid with the USER_ID body and the property ID', async () => {
    const { calls, request } = recorder();
    const result = await createGa4Deletion({ propertyId: '123456789', request })('u1');
    assert.deepEqual(result, { outcome: 'requested', status: 200 });
    assert.equal(calls.length, 1);
    assert.equal(calls[0].url, USER_DELETION_URL);
    assert.equal(calls[0].method, 'POST');
    assert.deepEqual(calls[0].data, {
      kind: 'analytics#userDeletionRequest',
      id: { type: 'USER_ID', userId: 'u1' },
      propertyId: '123456789',
    });
  });

  for (const propertyId of [undefined, '', '   ', 'abc', '12 34', '123456789; drop']) {
    it(`makes no call and reports not-configured for property ID ${JSON.stringify(propertyId)}`, async () => {
      const { calls, request } = recorder();
      const result = await createGa4Deletion({ propertyId, request })('u1');
      assert.deepEqual(result, { outcome: 'not-configured', status: null });
      assert.equal(calls.length, 0);
    });
  }

  it('turns an HTTP failure into outcome failed and never leaks the uid', async () => {
    const failing = async (options) => {
      const e = new Error(`Request failed with status code 403 for ${JSON.stringify(options.data)}`);
      e.response = { status: 403, data: options.data };
      e.config = options;
      throw e;
    };
    const { request } = recorder(failing);
    const result = await createGa4Deletion({ propertyId: '123456789', request })('secret-uid-1');
    assert.deepEqual(result, { outcome: 'failed', status: 403 });
    assert.ok(!JSON.stringify(result).includes('secret-uid-1'));
  });

  it('keeps only a short network error code when there is no HTTP status', async () => {
    const down = async () => {
      const e = new Error('connect ECONNRESET for secret-uid-1');
      e.code = 'ECONNRESET';
      throw e;
    };
    const result = await createGa4Deletion({ propertyId: '123456789', request: down })('secret-uid-1');
    assert.deepEqual(result, { outcome: 'failed', status: null, code: 'ECONNRESET' });
    assert.ok(!JSON.stringify(result).includes('secret-uid-1'));
  });

  it('drops an error code that is not a short identifier', async () => {
    const odd = async () => {
      const e = new Error('x');
      e.code = 'failed for secret-uid-1';
      throw e;
    };
    const result = await createGa4Deletion({ propertyId: '123456789', request: odd })('secret-uid-1');
    assert.deepEqual(result, { outcome: 'failed', status: null });
  });
});
