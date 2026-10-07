# Engineering Review RSI Learning Log

This log contains durable, evidence-validated lessons for the autonomous engineering review process. It must not contain secrets, customer data, raw logs, or transient PR chatter.

## Security trust-boundary review

### Pattern

For any deployable service, independently evaluate the relationship between:

1. network exposure / listener binding,
2. authentication and authorization,
3. mutation and administrative endpoint surface,
4. credentials/secrets available to the process,
5. CORS and other browser-policy configuration.

Treat these as separate controls. CORS is not authentication.

### Why the previous review heuristic was insufficient

A prior review process could identify architecture, dependency, CI, and code-level risks while failing to explicitly ask whether a newly deployable control plane had an authenticated trust boundary.

An external reviewer also missed the same class of issue. Consensus therefore provides no evidence that this control is safe.

### Evidence

A reviewed deployable FastAPI control plane exposed mutating endpoints without authentication/authorization while its container configuration published the backend port and allowed permissive CORS. The process could also receive provider credentials.

The security consequence follows from the code and deployment configuration, not from reviewer consensus: network reachability plus unauthenticated mutation endpoints creates an unauthorized control-plane surface.

### Improved heuristic

For every new or materially changed server/service deployment, run an explicit **Trust Boundary Pass** before approval:

- Who can reach the service?
- Is the listener localhost-only, private-network-only, or internet-reachable?
- What authenticates the caller?
- What authorizes each mutation class?
- Which endpoints can change settings, content, schedules, publishing, data, or credentials?
- What secrets are available to the service process?
- Does CORS merely restrict browser origins, or is someone incorrectly treating it as access control?
- Are unauthenticated negative tests present for every security-sensitive mutation?
- Is the secure deployment configuration the default, rather than an operator assumption?

A missing authentication/authorization boundary with reachable privileged mutation endpoints is a **P0/P1 candidate** and must be reproduced against the exact deployment configuration before verdict.

### Confidence

**HIGH** — the heuristic is directly grounded in an independently reproduced security finding. It should remain a review rule unless later evidence demonstrates that the apparent exposure is not reachable or the endpoints are protected by another verified boundary.

## RSI maintenance rule

When a finding is later corrected, disproved, or exposed by production/tests:

- preserve the original disagreement;
- record the evidence that resolved it;
- strengthen or weaken the heuristic only from evidence;
- prefer a small number of reusable checks over accumulating project-specific anecdotes.

Do not promote an external review finding into a rule merely because another reviewer raised it.
