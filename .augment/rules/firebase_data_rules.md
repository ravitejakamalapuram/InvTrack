---
type: "always_apply"
---

# Firebase & Data Integrity Rules – InvTrack

These rules ensure data consistency, offline-first behavior, and multi-tenant isolation.

---

## FIREBASE RULE 1: COLLECTION STRUCTURE
All user data MUST follow this pattern:
```
users/{userId}/collectionName/{documentId}
```

Current collections:
- `users/{userId}/investments`
- `users/{userId}/cashflows`
- `users/{userId}/goals`
- `users/{userId}/archivedInvestments`
- `users/{userId}/archivedCashflows`
- `users/{userId}/archivedGoals`

❌ Never create root-level collections for user data
❌ Never store user data without userId scoping

---

## FIREBASE RULE 2: OFFLINE-FIRST WRITE PATTERN
All Firestore writes MUST use the timeout pattern:
```dart
Future<void> _executeWrite(Future<void> Function() writeOperation) async {
  try {
    await writeOperation().timeout(_writeTimeout);
  } on TimeoutException {
    // Write cached locally, will sync when online
  }
}
```

This ensures:
- Writes don't block UI when offline
- Data is cached locally by Firestore
- Automatic sync when connection restored

---

## FIREBASE RULE 3: NEW COLLECTION CHECKLIST
Before creating any new Firestore collection:

### 3.1 Security Rules
- [ ] Add read/write rules to `firestore.rules`
- [ ] Ensure only authenticated user can access their data
- [ ] Test with Firebase Emulator

### 3.2 Indexes
- [ ] Add compound indexes to `firestore.indexes.json` if needed
- [ ] Deploy indexes before using queries

### 3.3 Data Lifecycle
- [ ] Add to delete account flow (`deleteUserData()`)
- [ ] Add to export service (`DataExportService`)
- [ ] Add to import service (`DataImportService`)
- [ ] Handle in archive/restore flows if applicable

### 3.4 Repository Pattern
- [ ] Create repository interface in domain layer
- [ ] Create Firestore implementation in data layer
- [ ] Create provider in presentation layer
- [ ] Never expose Firestore directly to UI

---

## FIREBASE RULE 4: BATCH OPERATIONS
Use batch writes for related operations:
```dart
final batch = _firestore.batch();
batch.set(ref1, data1);
batch.delete(ref2);
await _executeWrite(() => batch.commit());
```

Required for:
- Moving data between collections (archive/restore)
- Deleting parent with children (investment + cashflows)
- Bulk imports

Batch limit: 500 operations per batch

---

## FIREBASE RULE 5: TIMESTAMP HANDLING
- Always use `FieldValue.serverTimestamp()` for writes
- Store as Firestore Timestamp, not DateTime string
- Convert to DateTime in model layer:
```dart
createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
```

---

## FIREBASE RULE 6: DOCUMENT ID STRATEGY
- Use UUID v4 for client-generated IDs
- Use Firestore auto-ID only when order doesn't matter
- Never use sequential IDs (security risk)
- Store ID in document for easy access:
```dart
_investmentFromFirestore(doc.data(), doc.id)
```

---

## FIREBASE RULE 7: QUERY OPTIMIZATION
- Always add `.orderBy()` for consistent pagination
- Use `.limit()` for large collections
- Prefer `.where()` over client-side filtering
- Cache query results in providers when appropriate
- Use streams (`snapshots()`) for real-time updates

---

## FIREBASE RULE 8: ERROR HANDLING
Handle these Firestore errors explicitly:
- `permission-denied` → User not authenticated or unauthorized
- `unavailable` → Offline, data will sync later
- `not-found` → Document doesn't exist
- `already-exists` → Duplicate document

---

## FIREBASE RULE 9: DATA VALIDATION
Before writing to Firestore:
- Validate required fields are not null
- Validate string lengths (Firestore limit: 1MB per document)
- Validate numeric ranges
- Sanitize user input (prevent injection)
- Validate enum values

---

## FIREBASE RULE 10: MIGRATION STRATEGY
For schema changes:
- Add new fields with defaults (backward compatible)
- Never remove fields immediately
- Use versioning if major schema change
- Migrate data lazily on read when possible
- Document migration in CHANGELOG

