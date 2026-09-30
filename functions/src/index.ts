import { initializeApp } from 'firebase-admin/app';

initializeApp();

// cleanupOldAnonymousUsers (./cleanupAnonymousUsers) is intentionally NOT
// exported: deploying it would start deleting inactive guest accounts, which
// is a product decision, not part of APP-278.
export { deleteUserData, onAuthUserDeleted } from './deleteUserData';
