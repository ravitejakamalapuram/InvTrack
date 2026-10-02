// Read-back verifier. Deliberately shares no code or state with delete.mjs: it re-reads the
// real stores and reports every mismatch. Problem texts never contain the raw uid.

async function countRefs(ref) {
  let n = 0;
  for (const col of await ref.listCollections()) {
    for (const doc of await col.listDocuments()) {
      n += 1 + (await countRefs(doc));
    }
  }
  return n;
}

export async function verifyUserGone({ db, auth, uid }) {
  const problems = [];
  const ref = db.collection('users').doc(uid);

  if ((await ref.get()).exists) problems.push('users/<uid> document still exists');

  const collections = await ref.listCollections();
  if (collections.length > 0) {
    problems.push(`subcollections still exist: ${collections.map((c) => c.id).join(', ')}`);
  }

  const remaining = await countRefs(ref);
  if (remaining > 0) problems.push(`${remaining} document path(s) still exist under users/<uid>`);

  try {
    await auth.getUser(uid);
    problems.push('auth user still exists');
  } catch (e) {
    if (e.code !== 'auth/user-not-found') {
      problems.push(`auth lookup failed: ${e.code ?? e.message}`);
    }
  }

  return { ok: problems.length === 0, problems };
}
