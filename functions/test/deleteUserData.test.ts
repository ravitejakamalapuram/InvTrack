import type { Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

// In-memory stand-in for the users/{uid} tree: a set of document paths.
// recursiveDelete removes every path at or below the given document, like the
// Admin SDK does; listCollections reports subcollections that still hold docs.
class FakeDb {
  paths = new Set<string>();
  recursiveDeleteCalls: string[] = [];
  failNextDelete: Error | null = null;
  keepAfterDelete: string[] = [];

  constructor(paths: string[]) {
    paths.forEach((p) => this.paths.add(p));
  }

  collection(name: string) {
    return {
      doc: (id: string) => {
        const path = `${name}/${id}`;
        return {
          path,
          listCollections: async () => {
            const ids = new Set<string>();
            for (const p of this.paths) {
              if (p.startsWith(`${path}/`)) {
                ids.add(p.slice(path.length + 1).split('/')[0]);
              }
            }
            return [...ids].map((id) => ({ id }));
          },
        };
      },
    };
  }

  async recursiveDelete(ref: { path: string }) {
    this.recursiveDeleteCalls.push(ref.path);
    if (this.failNextDelete) {
      const e = this.failNextDelete;
      this.failNextDelete = null;
      // A partial run: delete half, then fail (like a crash mid-way).
      const under = [...this.paths].filter((p) => p.startsWith(ref.path));
      under.slice(0, Math.floor(under.length / 2)).forEach((p) => this.paths.delete(p));
      throw e;
    }
    for (const p of [...this.paths]) {
      if (p === ref.path || p.startsWith(`${ref.path}/`)) this.paths.delete(p);
    }
    this.keepAfterDelete.forEach((p) => this.paths.add(p));
  }

  remainingUnder(uid: string) {
    return [...this.paths].filter((p) => p.startsWith(`users/${uid}`));
  }
}

let mockDb: FakeDb;
jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => mockDb,
}));

import {
  deleteAllUserData,
  deleteUserData,
  handleDeleteUserData,
} from '../src/deleteUserData';

const asDb = (db: FakeDb) => db as unknown as Firestore;

function seed(): FakeDb {
  return new FakeDb([
    'users/alice',
    'users/alice/investments/i1',
    'users/alice/cashflows/c1',
    'users/alice/cashflows/c2',
    // A collection the app's hard-coded list has never heard of:
    'users/alice/someFutureFeature/x',
    // Nested subcollection:
    'users/alice/investments/i1/notes/n1',
    'users/bob/investments/b1',
  ]);
}

describe('deleteAllUserData', () => {
  it('deletes the user doc and ALL subcollections, including unknown and nested ones', async () => {
    const db = seed();
    await deleteAllUserData(asDb(db), 'alice');
    expect(db.remainingUnder('alice')).toEqual([]);
    expect(db.recursiveDeleteCalls).toEqual(['users/alice']);
  });

  it('never touches other users', async () => {
    const db = seed();
    await deleteAllUserData(asDb(db), 'alice');
    expect(db.remainingUnder('bob')).toEqual(['users/bob/investments/b1']);
  });

  it('is resumable: a retry after a partial failure finishes the job', async () => {
    const db = seed();
    db.failNextDelete = new Error('connection reset');
    await expect(deleteAllUserData(asDb(db), 'alice')).rejects.toThrow('connection reset');
    expect(db.remainingUnder('alice').length).toBeGreaterThan(0);

    await deleteAllUserData(asDb(db), 'alice');
    expect(db.remainingUnder('alice')).toEqual([]);
  });

  it('is idempotent when there is nothing left to delete', async () => {
    const db = new FakeDb([]);
    await expect(deleteAllUserData(asDb(db), 'alice')).resolves.toBeUndefined();
  });

  it('throws if data is still present after the delete (not confirmed)', async () => {
    const db = seed();
    db.keepAfterDelete = ['users/alice/cashflows/late'];
    await expect(deleteAllUserData(asDb(db), 'alice')).rejects.toThrow(/cashflows/);
  });

  it('refuses an empty uid instead of deleting the users collection', async () => {
    const db = seed();
    await expect(deleteAllUserData(asDb(db), '')).rejects.toThrow(/uid is required/);
    expect(db.recursiveDeleteCalls).toEqual([]);
  });
});

describe('handleDeleteUserData', () => {
  it('rejects unauthenticated callers', async () => {
    const del = jest.fn();
    await expect(handleDeleteUserData(undefined, del)).rejects.toMatchObject({
      code: 'unauthenticated',
    });
    expect(del).not.toHaveBeenCalled();
  });

  it('returns {deleted: true} only after the delete completes', async () => {
    const del = jest.fn().mockResolvedValue(undefined);
    await expect(handleDeleteUserData('alice', del)).resolves.toEqual({ deleted: true });
    expect(del).toHaveBeenCalledWith('alice');
  });

  it('maps a failed delete to a retryable internal HttpsError', async () => {
    const del = jest.fn().mockRejectedValue(new Error('boom'));
    const err = await handleDeleteUserData('alice', del).catch((e) => e);
    expect(err).toBeInstanceOf(HttpsError);
    expect(err.code).toBe('internal');
  });
});

describe('deleteUserData callable', () => {
  it('deletes the CALLER\'s data and ignores any uid in the request body', async () => {
    mockDb = seed();
    const result = await deleteUserData.run({
      auth: { uid: 'alice', token: {} },
      data: { uid: 'bob' },
    } as never);
    expect(result).toEqual({ deleted: true });
    expect(mockDb.remainingUnder('alice')).toEqual([]);
    expect(mockDb.remainingUnder('bob')).toEqual(['users/bob/investments/b1']);
  });

  it('rejects a call with no auth', async () => {
    mockDb = seed();
    await expect(deleteUserData.run({ data: {} } as never)).rejects.toMatchObject({
      code: 'unauthenticated',
    });
    expect(mockDb.recursiveDeleteCalls).toEqual([]);
  });
});
