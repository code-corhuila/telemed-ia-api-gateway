\## User story



<!--

Reference to the story in telemed-ia-docs:

code-corhuila/telemed-ia-docs#NN

If this PR is infrastructure or tooling, write N/A and explain why.

\-->



\## What changes and why



<!--

3-5 lines: the problem this PR solves and the decision taken.

If the change is purely gateway configuration, say so.

\-->



\## How it was tested



<!--

\- nginx -t inside the container.

\- Result of tests/smoke.sh.

\- Result of the CI workflow (green/red).

\-->



\## Promotion trace



<!--

Only for PRs targeting `qa` or `main`.

List each re-applied commit with its traceability line:



\- chore(gateway): some change

&#x20; - cherry picked from commit <sha-in-origin>



For PRs targeting `develop`, write: N/A — PR targeting develop.

\-->



N/A — PR targeting develop.



\## Checklist



\- \[ ] No secrets or real credentials committed.

\- \[ ] No schema changes outside the `-db` repos.

\- \[ ] The gateway still rejects protected routes without credentials.

\- \[ ] The common error envelope is preserved (401/404/429/503).

\- \[ ] The three permanent branches remain intact.

\- \[ ] Commit messages follow Conventional Commits.

\- \[ ] Affected documentation updated.

