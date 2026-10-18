import test from 'node:test';
import assert from 'node:assert/strict';
import { buildBody } from '../file-crash-issues.mjs';

test('body carries the dedupe marker and stack but no user identifiers', () => {
  const body = buildBody(
    { issue: { id: 'abc123', errorType: 'FATAL', title: 'Boom', metrics: [] }, metrics: [{ eventsCount: '3', impactedUsersCount: '2' }] },
    { user: { id: 'secret-user' }, installationUuid: 'secret-inst', exceptions: [{ type: 'StateError', frames: [{ symbol: 'a.b', file: 'x.dart', line: '9', blamed: true }] }] },
  );
  assert.match(body, /<!-- crashlytics-issue:abc123 -->/);
  assert.match(body, />> a\.b {2}\(x\.dart:9\)/);
  assert.match(body, /Events in window: 3, users impacted: 2/);
  assert.doesNotMatch(body, /secret/);
});
