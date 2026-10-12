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

if [ "$FAILED" -eq 0 ]; then
    echo "All smoke tests passed."
    exit 0
else
    echo "$FAILED smoke test(s) failed."
    exit 1
fi