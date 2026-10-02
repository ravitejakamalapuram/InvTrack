// Deletes everything we hold for one uid: the whole users/{uid} tree (any depth, known or
// unknown subcollections) and the Firebase Auth account. Idempotent: safe to re-run.

/** Counts the documents that actually exist under a document reference (recursive). */
export async function countDocs(ref) {
  let n = 0;
  for (const col of await ref.listCollections()) {
    for (const doc of await col.listDocuments()) {
      if ((await doc.get()).exists) n += 1;
      n += await countDocs(doc);
    }
  }
  return n;
}

export async function deleteUserData({ db, auth, uid }) {
  const ref = db.collection('users').doc(uid);
  const docsDeleted = (await ref.get()).exists ? 1 + (await countDocs(ref)) : await countDocs(ref);
  await db.recursiveDelete(ref);
  let authDeleted = true;
  try {
    await auth.deleteUser(uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    authDeleted = false;
  }
  return { docsDeleted, authDeleted };
}
