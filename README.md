# telemed-ia-api-gateway

Single entry point of the **TeleMed IA** system.

Part of team `telemed-ia`, Grupo 2.

## What this repo is

The gateway is **configuration, not code**. It routes external traffic to
domain services, filters credentials, applies CORS and rate limits, propagates
`X-Correlation-Id`, and returns its own errors with the common envelope.

It does **not** validate tokens. Token validation happens in every service,
because internal calls between services do not go through the gateway
(norm 5.6.2).

## What the gateway does and does not do

| Responsibility | Where |
|---|---|
| Route `/api/v1/<domain>/…` to the correct service | here |
| Reject a protected route with no `Authorization` header | here |
| Rate limit and CORS | here |
| Reuse or generate `X-Correlation-Id`, forward it, echo it, log it | here |
| Respond its own errors with the common envelope | here |
| Validate the token (signature, expiration, claims) | **in every service** |
| Business rules | never here |
| Database | never here |

## Repository layout

```text
.
├── deploy/
│   ├── Dockerfile               nginx image with the configuration
│   └── compose.yml              publishes port 8000 to the host
├── nginx/
│   ├── nginx.conf               global settings, JSON logs
│   ├── conf.d/
│   │   ├── 00-resolver.conf     per-request DNS resolution
│   │   ├── 10-security.conf     rate limit, CORS, correlation id, credential filter
│   │   └── 20-server.conf       server, own errors, inclusion of routes
│   ├── snippets/
│   │   └── headers.conf         headers carried by every response
│   └── routes/
│       ├── _health.conf         placeholder
│       └── patient.conf         routing to patients-api
├── tests/
│   └── smoke.sh                 health, 404, 401, correlation, CORS
├── .env.example
├── .dockerignore
├── .gitattributes
├── .gitignore
└── README.md
```

---
## Local development

```text
docker network create platform    # once, if it does not already exist
docker compose -f deploy/compose.yml up -d --build
bash tests/smoke.sh
```
> The gateway is then reachable at http://localhost:8000.

## Adding a new domain
1. Create `nginx/routes/<domain>.conf` with its `location` blocks.
2. Use a variable in `proxy_pass` so DNS resolution happens per request:
```TypeScrypt
set $identity_api http://identity-api:8080;
proxy_pass $identity_api;
```
3. Include `snippets/headers.conf` if the location adds its own headers.
4. Run `bash tests/smoke.sh` to confirm nothing broke.

---
## Its own errors
| Situation | Response |
|---|---|
| Protected route with no credentials | `401 {"error":"UNAUTHORIZED", …, "traceId"}` |
| Unknown route | `404 {"error":"NOT_FOUND", …}` |
| Rate limit exceeded | `429 {"error":"TOO_MANY_REQUESTS", …}` with `Retry-After` |
| Downstream service unavailable | `503 {"error":"SERVICE_UNAVAILABLE", …}` |

Errors returned by a service pass through untouched: they already use the same
envelope. The `traceId` is the same `X-Correlation-Id` that reached the service.

## Related documentation
* `Annex F of the repo norm`.

* `telemed-ia-docs/00-governance/branching-policy.md`

* `telemed-ia-docs/05-architecture/decisions/records/`