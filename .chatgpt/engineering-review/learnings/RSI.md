# RSI Learning

Validated security lesson: for deployable services, independently verify network exposure, authentication/authorization, privileged mutation surface, process secrets, and CORS. CORS is not authentication.

Evidence came from an independently reproduced control-plane exposure where reachable unauthenticated mutation endpoints combined with permissive deployment configuration created an unauthorized trust boundary.

Improved heuristic: run a Trust Boundary Pass before approval of materially changed server deployments. Verify who can reach the service, caller authentication, mutation authorization, privileged endpoints, secret access, secure defaults, and negative auth tests.

Confidence: HIGH. Revisit only if later evidence disproves the exposure or establishes another verified boundary.

RSI rule: preserve disagreements until evidence resolves them; strengthen heuristics only from evidence; prefer reusable checks over anecdotes.