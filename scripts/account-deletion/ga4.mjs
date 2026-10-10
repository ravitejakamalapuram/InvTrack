// Asks Google Analytics 4 to delete the events tied to one user ID (the User Deletion API, id type USER_ID).
// It never throws and never puts the uid in anything it returns: a failure must not block the Firestore and
// Auth deletion, and the result goes into the audit entry. Google deletes the data on its own schedule.
import { GoogleAuth } from 'google-auth-library';

export const USER_DELETION_URL = 'https://www.googleapis.com/analytics/v3/userDeletion/userDeletionRequests:upsert';
export const USER_DELETION_SCOPE = 'https://www.googleapis.com/auth/analytics.user.deletion';

/** Default HTTP client: Application Default Credentials (keyless, as the rest of the job) with the deletion scope. */
let authClient;
const authorizedRequest = async (options) => {
  authClient ??= new GoogleAuth({ scopes: [USER_DELETION_SCOPE] }).getClient();
  return (await authClient).request(options);
};

const isHttpStatus = (n) => Number.isInteger(n) && n >= 100 && n <= 599;

/**
 * @param {object} args
 * @param {string} [args.propertyId] GA4 property ID (digits only, GA4_PROPERTY_ID). Unset or malformed: nothing is sent.
 * @param {(options: {url: string, method: string, data: object}) => Promise<{status?: number}>} [args.request]
 * @returns {(uid: string) => Promise<{outcome: 'requested' | 'failed' | 'not-configured', status: number | null, code?: string}>}
 */
export function createGa4Deletion({ propertyId, request = authorizedRequest } = {}) {
  const property = typeof propertyId === 'string' ? propertyId.trim() : '';
  const configured = /^\d+$/.test(property);

  return async (uid) => {
    if (!configured) return { outcome: 'not-configured', status: null };
    try {
      const res = await request({
        url: USER_DELETION_URL,
        method: 'POST',
        data: {
          kind: 'analytics#userDeletionRequest',
          id: { type: 'USER_ID', userId: uid },
          propertyId: property,
        },
      });
      return { outcome: 'requested', status: isHttpStatus(res?.status) ? res.status : null };
    } catch (e) {
      // Only a status number or a short code: an error message or request config can carry the uid.
      const status = e?.response?.status;
      const result = { outcome: 'failed', status: isHttpStatus(status) ? status : null };
      if (result.status === null && typeof e?.code === 'string' && /^[A-Za-z0-9_.-]{1,40}$/.test(e.code)) {
        result.code = e.code;
      }
      return result;
    }
  };
}
