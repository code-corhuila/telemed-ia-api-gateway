#!/usr/bin/env bash
set -euo pipefail

GATEWAY="${1:-http://localhost:8000}"
FAILED=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ok   $name ($actual)"
    else
        echo "  FAIL $name (expected $expected, got $actual)"
        FAILED=$((FAILED + 1))
    fi
}

echo "Smoke tests against $GATEWAY"

echo "1. /health returns 200"
code=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/health")
check "health status" "200" "$code"

echo "2. unknown route returns 404 with the common envelope"
body=$(curl -s "$GATEWAY/api/v1/does-not-exist")
code=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/api/v1/does-not-exist")
check "unknown route status" "404" "$code"
echo "$body" | grep -q '"error":"NOT_FOUND"' && echo "  ok   error envelope" || { echo "  FAIL error envelope"; FAILED=$((FAILED + 1)); }

echo "3. protected route without Authorization returns 401"
code=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/api/v1/patients/me")
check "protected without token" "401" "$code"

echo "4. X-Correlation-Id is echoed back"
received=$(curl -s -D - -o /dev/null -H "X-Correlation-Id: test-correlation-123" "$GATEWAY/health" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-correlation-id" {print $2}')
check "correlation echo" "test-correlation-123" "$received"

echo "5. X-Correlation-Id is generated when missing"
received=$(curl -s -D - -o /dev/null "$GATEWAY/health" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-correlation-id" {print $2}')
if [ -n "$received" ]; then echo "  ok   correlation generated ($received)"; else echo "  FAIL no correlation id"; FAILED=$((FAILED + 1)); fi

echo "6. CORS preflight from a known origin returns 204"
code=$(curl -s -o /dev/null -w '%{http_code}' -X OPTIONS \
    -H "Origin: http://localhost:4200" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: Idempotency-Key" \
    "$GATEWAY/api/v1/__options__")
check "preflight status" "204" "$code"

echo "7. auth routes are public and reach identity-api"
# No Authorization header: the gateway itself must not reject the request
# (UNAUTHORIZED) nor miss the route (NOT_FOUND). identity-api may answer
# INVALID_CREDENTIALS, or the gateway SERVICE_UNAVAILABLE when it is down.
body=$(curl -s -X POST -H 'Content-Type: application/json' \
    -d '{"email":"smoke@example.com","password":"not-a-real-password"}' \
    "$GATEWAY/api/v1/auth/login")
if echo "$body" | grep -qE '"error":"(UNAUTHORIZED|NOT_FOUND)"'; then
    echo "  FAIL auth route ($body)"; FAILED=$((FAILED + 1))
else
    echo "  ok   auth route reaches identity-api or reports it unavailable"
fi

echo "8. agent route without Authorization returns 401"
code=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/api/v1/agent/conversations?appointmentId=00000000-0000-4000-8000-000000000000")
check "agent without token" "401" "$code"

echo "9. agent route with a bearer token reaches intelligent-agent-api"
# The gateway must not miss the route (NOT_FOUND). The agent validates the
# token itself and may answer UNAUTHORIZED, or the gateway SERVICE_UNAVAILABLE
# when the agent is down.
body=$(curl -s -H 'Authorization: Bearer not-a-real-token' \
    "$GATEWAY/api/v1/agent/conversations?appointmentId=00000000-0000-4000-8000-000000000000")
if echo "$body" | grep -q '"error":"NOT_FOUND"'; then
    echo "  FAIL agent route ($body)"; FAILED=$((FAILED + 1))
else
    echo "  ok   agent route reaches intelligent-agent-api or reports it unavailable"
fi

echo "10. document route without Authorization returns 401"
code=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/api/v1/documents")
check "documents without token" "401" "$code"

echo "11. document route with a bearer token reaches document-generation-api"
# The gateway must not miss the route (NOT_FOUND). The service validates the
# token itself and may answer UNAUTHORIZED, or the gateway SERVICE_UNAVAILABLE
# when the service is down.
body=$(curl -s -H 'Authorization: Bearer not-a-real-token' "$GATEWAY/api/v1/documents")
if echo "$body" | grep -q '"error":"NOT_FOUND"'; then
    echo "  FAIL document route ($body)"; FAILED=$((FAILED + 1))
else
    echo "  ok   document route reaches document-generation-api or reports it unavailable"
fi

echo "12. professional route without Authorization returns 401"
code=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/api/v1/professionals")
check "professionals without token" "401" "$code"

echo "13. professional route with a bearer token reaches professional-management-api"
# The gateway must not miss the route (NOT_FOUND). The service validates the
# token itself and may answer UNAUTHORIZED, or the gateway SERVICE_UNAVAILABLE
# when the service is down.
body=$(curl -s -H 'Authorization: Bearer not-a-real-token' "$GATEWAY/api/v1/professionals")
if echo "$body" | grep -q '"error":"NOT_FOUND"'; then
    echo "  FAIL professional route ($body)"; FAILED=$((FAILED + 1))
else
    echo "  ok   professional route reaches professional-management-api or reports it unavailable"
fi

echo "14. notifications route without Authorization returns 401"
code=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/api/v1/notifications")
check "notifications without token" "401" "$code"

echo "15. notifications route with a bearer token reaches notifications-api"
# The gateway must not miss the route (NOT_FOUND). The service validates the
# token itself and may answer UNAUTHORIZED, or the gateway SERVICE_UNAVAILABLE
# when the service is down.
body=$(curl -s -H 'Authorization: Bearer not-a-real-token' "$GATEWAY/api/v1/notifications/unread-count")
if echo "$body" | grep -q '"error":"NOT_FOUND"'; then
    echo "  FAIL notifications route ($body)"; FAILED=$((FAILED + 1))
else
    echo "  ok   notifications route reaches notifications-api or reports it unavailable"
fi

if [ "$FAILED" -eq 0 ]; then
    echo "All smoke tests passed."
    exit 0
else
    echo "$FAILED smoke test(s) failed."
    exit 1
fi