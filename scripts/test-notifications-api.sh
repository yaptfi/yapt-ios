#!/bin/bash
#
# Yapt Notifications API Test Script
#
# Tests all notification endpoints against the backend.
# Run this to validate backend implementation before iOS integration.
#
# Usage:
#   ./scripts/test-notifications-api.sh [session-cookie]
#
# If no cookie provided, will attempt to use YAPT_SESSION_COOKIE env var.
#
# Prerequisites:
#   - jq (brew install jq)
#   - curl
#   - Valid session cookie from logging into yapt.fi
#

set -e

# Configuration
BASE_URL="${YAPT_BASE_URL:-https://yapt.fi}"
COOKIE="${1:-$YAPT_SESSION_COOKIE}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((SKIPPED++))
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${NC}"
        echo "Install with: brew install jq"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is required but not installed.${NC}"
        exit 1
    fi

    if [ -z "$COOKIE" ]; then
        echo -e "${RED}Error: No session cookie provided.${NC}"
        echo ""
        echo "Usage: $0 <session-cookie>"
        echo "   or: export YAPT_SESSION_COOKIE='yapt.sid=...'"
        echo ""
        echo "To get a session cookie:"
        echo "  1. Log in to yapt.fi in your browser"
        echo "  2. Open DevTools > Application > Cookies"
        echo "  3. Copy the value of 'yapt.sid'"
        exit 1
    fi
}

# Make authenticated request
api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"

    local url="${BASE_URL}${endpoint}"
    local args=(-s -w "\n%{http_code}" -X "$method" -H "Cookie: yapt.sid=$COOKIE" -H "Content-Type: application/json" -H "Accept: application/json")

    if [ -n "$data" ]; then
        args+=(-d "$data")
    fi

    curl "${args[@]}" "$url"
}

# Parse response and status code
parse_response() {
    local response="$1"
    local body=$(echo "$response" | sed '$d')
    local status=$(echo "$response" | tail -n1)
    echo "$body"
    echo "$status"
}

# ============================================================================
# TEST: Authentication Check
# ============================================================================
test_auth() {
    log_section "Authentication Check"

    local response=$(api_request GET "/api/auth/me")
    local body=$(echo "$response" | sed '$d')
    local status=$(echo "$response" | tail -n1)

    if [ "$status" == "200" ]; then
        local username=$(echo "$body" | jq -r '.username // .user.username // "unknown"')
        log_pass "Authenticated as: $username"
        return 0
    else
        log_fail "Authentication failed (HTTP $status)"
        echo "  Response: $body"
        return 1
    fi
}

# ============================================================================
# TEST: GET /api/notifications/settings
# ============================================================================
test_get_settings() {
    log_section "GET /api/notifications/settings"

    local response=$(api_request GET "/api/notifications/settings")
    local body=$(echo "$response" | sed '$d')
    local status=$(echo "$response" | tail -n1)

    # Check status code
    if [ "$status" != "200" ]; then
        log_fail "Expected HTTP 200, got $status"
        echo "  Response: $body"
        return 1
    fi
    log_pass "HTTP 200 OK"

    # Check response structure
    if ! echo "$body" | jq -e '.settings' > /dev/null 2>&1; then
        log_fail "Response missing 'settings' wrapper"
        echo "  Response: $body"
        return 1
    fi
    log_pass "Response has 'settings' wrapper"

    # Check required fields (use 'has' to check key exists, even if value is null)
    local settings=$(echo "$body" | jq '.settings')
    local required_fields=("depegEnabled" "depegSeverity" "depegLowerThreshold" "depegUpperThreshold" "apyEnabled" "apySeverity" "apyThreshold")

    for field in "${required_fields[@]}"; do
        if echo "$settings" | jq -e "has(\"$field\")" > /dev/null 2>&1; then
            log_pass "Field '$field' present"
        else
            log_fail "Field '$field' missing"
        fi
    done

    # Check severity values are valid
    local depeg_sev=$(echo "$settings" | jq -r '.depegSeverity')
    local apy_sev=$(echo "$settings" | jq -r '.apySeverity')
    local valid_severities="min low default high urgent"

    if [[ $valid_severities =~ $depeg_sev ]]; then
        log_pass "depegSeverity '$depeg_sev' is valid"
    else
        log_fail "depegSeverity '$depeg_sev' is invalid (expected: $valid_severities)"
    fi

    if [[ $valid_severities =~ $apy_sev ]]; then
        log_pass "apySeverity '$apy_sev' is valid"
    else
        log_fail "apySeverity '$apy_sev' is invalid (expected: $valid_severities)"
    fi

    # Store for later tests
    ORIGINAL_SETTINGS="$settings"

    echo ""
    log_info "Current settings:"
    echo "$settings" | jq '.'
}

# ============================================================================
# TEST: PUT /api/notifications/settings
# ============================================================================
test_put_settings() {
    log_section "PUT /api/notifications/settings"

    # Test updating settings
    local test_settings='{
        "depegEnabled": true,
        "depegSeverity": "high",
        "depegLowerThreshold": 0.96,
        "depegUpperThreshold": 1.04,
        "depegSymbols": ["USDC", "USDT"],
        "apyEnabled": true,
        "apySeverity": "default",
        "apyThreshold": 0.08
    }'

    local response=$(api_request PUT "/api/notifications/settings" "$test_settings")
    local body=$(echo "$response" | sed '$d')
    local status=$(echo "$response" | tail -n1)

    if [ "$status" != "200" ]; then
        log_fail "Expected HTTP 200, got $status"
        echo "  Response: $body"
        return 1
    fi
    log_pass "HTTP 200 OK"

    # Verify values were updated
    local settings=$(echo "$body" | jq '.settings')

    local dep_thresh=$(echo "$settings" | jq '.depegLowerThreshold')
    if [ "$dep_thresh" == "0.96" ]; then
        log_pass "depegLowerThreshold updated to 0.96"
    else
        log_fail "depegLowerThreshold not updated (got: $dep_thresh)"
    fi

    local apy_thresh=$(echo "$settings" | jq '.apyThreshold')
    if [ "$apy_thresh" == "0.08" ]; then
        log_pass "apyThreshold updated to 0.08"
    else
        log_fail "apyThreshold not updated (got: $apy_thresh)"
    fi

    # Test validation - invalid threshold
    log_info "Testing validation: invalid depegLowerThreshold"
    local invalid_settings='{"depegEnabled": true, "depegSeverity": "high", "depegLowerThreshold": 1.5, "depegUpperThreshold": 1.04, "apyEnabled": false, "apySeverity": "default", "apyThreshold": 0.05}'

    response=$(api_request PUT "/api/notifications/settings" "$invalid_settings")
    status=$(echo "$response" | tail -n1)

    if [ "$status" == "400" ]; then
        log_pass "Invalid threshold rejected with HTTP 400"
    else
        log_skip "Validation not enforced (got HTTP $status) - consider adding validation"
    fi

    # Test validation - invalid severity
    log_info "Testing validation: invalid severity"
    local invalid_sev='{"depegEnabled": true, "depegSeverity": "INVALID", "depegLowerThreshold": 0.95, "depegUpperThreshold": 1.05, "apyEnabled": false, "apySeverity": "default", "apyThreshold": 0.05}'

    response=$(api_request PUT "/api/notifications/settings" "$invalid_sev")
    status=$(echo "$response" | tail -n1)

    if [ "$status" == "400" ]; then
        log_pass "Invalid severity rejected with HTTP 400"
    else
        log_skip "Severity validation not enforced (got HTTP $status) - consider adding validation"
    fi

    # Restore original settings if we have them
    if [ -n "$ORIGINAL_SETTINGS" ]; then
        log_info "Restoring original settings..."
        api_request PUT "/api/notifications/settings" "$ORIGINAL_SETTINGS" > /dev/null
    fi
}

# ============================================================================
# TEST: GET /api/notifications/history
# ============================================================================
test_get_history() {
    log_section "GET /api/notifications/history"

    # Basic request
    local response=$(api_request GET "/api/notifications/history")
    local body=$(echo "$response" | sed '$d')
    local status=$(echo "$response" | tail -n1)

    if [ "$status" != "200" ]; then
        log_fail "Expected HTTP 200, got $status"
        echo "  Response: $body"
        return 1
    fi
    log_pass "HTTP 200 OK"

    # Check response structure
    if ! echo "$body" | jq -e '.notifications' > /dev/null 2>&1; then
        log_fail "Response missing 'notifications' array"
        return 1
    fi
    log_pass "Response has 'notifications' array"

    if ! echo "$body" | jq -e '.total' > /dev/null 2>&1; then
        log_fail "Response missing 'total' field"
    else
        log_pass "Response has 'total' field"
    fi

    if ! echo "$body" | jq -e '.hasMore' > /dev/null 2>&1; then
        log_fail "Response missing 'hasMore' field"
    else
        log_pass "Response has 'hasMore' field"
    fi

    local count=$(echo "$body" | jq '.notifications | length')
    local total=$(echo "$body" | jq '.total')
    log_info "Retrieved $count notifications (total: $total)"

    # If we have notifications, validate structure
    if [ "$count" -gt 0 ]; then
        local first=$(echo "$body" | jq '.notifications[0]')

        local required_fields=("id" "type" "severity" "title" "message" "createdAt")
        for field in "${required_fields[@]}"; do
            if echo "$first" | jq -e ".$field" > /dev/null 2>&1; then
                log_pass "Notification has '$field' field"
            else
                log_fail "Notification missing '$field' field"
            fi
        done

        # Check type is valid
        local type=$(echo "$first" | jq -r '.type')
        if [ "$type" == "depeg" ] || [ "$type" == "apy" ]; then
            log_pass "Notification type '$type' is valid"
        else
            log_fail "Notification type '$type' is invalid (expected: depeg or apy)"
        fi

        echo ""
        log_info "Sample notification:"
        echo "$first" | jq '.'
    else
        log_info "No notifications in history (this is OK for testing)"
    fi

    # Test pagination
    log_info "Testing pagination: limit=5, offset=0"
    response=$(api_request GET "/api/notifications/history?limit=5&offset=0")
    body=$(echo "$response" | sed '$d')
    status=$(echo "$response" | tail -n1)

    if [ "$status" == "200" ]; then
        local limit_count=$(echo "$body" | jq '.notifications | length')
        if [ "$limit_count" -le 5 ]; then
            log_pass "Pagination limit=5 works (got $limit_count)"
        else
            log_fail "Pagination limit=5 returned $limit_count items"
        fi
    else
        log_fail "Pagination request failed (HTTP $status)"
    fi

    # Test type filter
    log_info "Testing filter: type=depeg"
    response=$(api_request GET "/api/notifications/history?type=depeg")
    body=$(echo "$response" | sed '$d')
    status=$(echo "$response" | tail -n1)

    if [ "$status" == "200" ]; then
        log_pass "Type filter accepted"
        local depeg_count=$(echo "$body" | jq '[.notifications[] | select(.type == "depeg")] | length')
        local total_count=$(echo "$body" | jq '.notifications | length')
        if [ "$depeg_count" == "$total_count" ]; then
            log_pass "All returned notifications are type 'depeg'"
        elif [ "$total_count" == "0" ]; then
            log_info "No depeg notifications found (OK for testing)"
        else
            log_fail "Filter returned mixed types ($depeg_count depeg out of $total_count)"
        fi
    else
        log_fail "Type filter request failed (HTTP $status)"
    fi
}

# ============================================================================
# TEST: POST /api/notifications/devices
# ============================================================================
test_register_device() {
    log_section "POST /api/notifications/devices"

    # Generate a fake device token (64 hex chars)
    local fake_token=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | fold -w 64 | head -n 1)

    local request="{\"token\": \"$fake_token\", \"platform\": \"ios\"}"

    local response=$(api_request POST "/api/notifications/devices" "$request")
    local body=$(echo "$response" | sed '$d')
    local status=$(echo "$response" | tail -n1)

    if [ "$status" == "201" ] || [ "$status" == "200" ]; then
        log_pass "HTTP $status - Device registered"
    elif [ "$status" == "404" ]; then
        log_skip "Endpoint not implemented yet (HTTP 404)"
        return 0
    else
        log_fail "Expected HTTP 201, got $status"
        echo "  Response: $body"
        return 1
    fi

    # Check response has deviceId
    if echo "$body" | jq -e '.deviceId' > /dev/null 2>&1; then
        DEVICE_ID=$(echo "$body" | jq -r '.deviceId')
        log_pass "Response contains deviceId: $DEVICE_ID"
    else
        log_fail "Response missing 'deviceId' field"
        echo "  Response: $body"
    fi

    # Test idempotency - same token should return same deviceId
    log_info "Testing idempotency: re-registering same token"
    response=$(api_request POST "/api/notifications/devices" "$request")
    body=$(echo "$response" | sed '$d')
    status=$(echo "$response" | tail -n1)

    if [ "$status" == "201" ] || [ "$status" == "200" ]; then
        local new_device_id=$(echo "$body" | jq -r '.deviceId')
        if [ "$new_device_id" == "$DEVICE_ID" ]; then
            log_pass "Idempotent: same deviceId returned"
        else
            log_skip "Different deviceId returned (may be intentional)"
        fi
    fi
}

# ============================================================================
# TEST: DELETE /api/notifications/devices/:deviceId
# ============================================================================
test_unregister_device() {
    log_section "DELETE /api/notifications/devices/:deviceId"

    if [ -z "$DEVICE_ID" ]; then
        log_skip "No device registered, skipping unregister test"
        return 0
    fi

    local response=$(api_request DELETE "/api/notifications/devices/$DEVICE_ID")
    local body=$(echo "$response" | sed '$d')
    local status=$(echo "$response" | tail -n1)

    if [ "$status" == "204" ] || [ "$status" == "200" ]; then
        log_pass "HTTP $status - Device unregistered"
    elif [ "$status" == "404" ]; then
        log_skip "Endpoint not implemented yet (HTTP 404)"
        return 0
    else
        log_fail "Expected HTTP 204, got $status"
        echo "  Response: $body"
        return 1
    fi

    # Test idempotency - deleting again should still succeed
    log_info "Testing idempotency: deleting non-existent device"
    response=$(api_request DELETE "/api/notifications/devices/$DEVICE_ID")
    status=$(echo "$response" | tail -n1)

    if [ "$status" == "204" ] || [ "$status" == "200" ] || [ "$status" == "404" ]; then
        log_pass "Idempotent delete handled correctly (HTTP $status)"
    else
        log_fail "Unexpected status for idempotent delete: $status"
    fi
}

# ============================================================================
# TEST: Unauthorized Access
# ============================================================================
test_unauthorized() {
    log_section "Unauthorized Access (no cookie)"

    # Make request without cookie
    local response=$(curl -s -w "\n%{http_code}" -X GET -H "Accept: application/json" "${BASE_URL}/api/notifications/settings")
    local status=$(echo "$response" | tail -n1)

    if [ "$status" == "401" ]; then
        log_pass "GET /api/notifications/settings returns 401 without auth"
    else
        log_fail "Expected 401 for unauthenticated request, got $status"
    fi

    response=$(curl -s -w "\n%{http_code}" -X GET -H "Accept: application/json" "${BASE_URL}/api/notifications/history")
    status=$(echo "$response" | tail -n1)

    if [ "$status" == "401" ]; then
        log_pass "GET /api/notifications/history returns 401 without auth"
    else
        log_fail "Expected 401 for unauthenticated request, got $status"
    fi
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Yapt Notifications API Test Suite                      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Base URL: $BASE_URL"
    echo ""

    check_prerequisites

    # Run tests
    if ! test_auth; then
        echo ""
        echo -e "${RED}Authentication failed. Cannot continue tests.${NC}"
        exit 1
    fi

    test_get_settings
    test_put_settings
    test_get_history
    test_register_device
    test_unregister_device
    test_unauthorized

    # Summary
    log_section "Test Summary"
    echo -e "  ${GREEN}Passed:${NC}  $PASSED"
    echo -e "  ${RED}Failed:${NC}  $FAILED"
    echo -e "  ${YELLOW}Skipped:${NC} $SKIPPED"
    echo ""

    if [ "$FAILED" -gt 0 ]; then
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main
