// Asks Google Analytics 4 to delete the events tied to one user ID (Analytics Admin API, properties.submitUserDeletion).
// The older v3 User Deletion API answers 404 for GA4 properties (seen on the first live run, 2026-10-20).
// It never throws and never puts the uid in anything it returns: a failure must not block the Firestore and
// Auth deletion, and the result goes into the audit entry. Google deletes the data on its own schedule.
import { GoogleAuth } from 'google-auth-library';

/** @param {string} property digits-only GA4 property ID (already validated by the caller) */
export const userDeletionUrl = (property) =>
  `https://analyticsadmin.googleapis.com/v1alpha/properties/${property}:submitUserDeletion`;
export const USER_DELETION_SCOPE = 'https://www.googleapis.com/auth/analytics.edit';

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
        url: userDeletionUrl(property),
        method: 'POST',
        data: { userId: uid },
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
