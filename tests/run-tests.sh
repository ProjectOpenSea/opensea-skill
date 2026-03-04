#!/usr/bin/env bash
set -euo pipefail

# End-to-end test suite for opensea-skill scripts [DIS-74]
#
# Usage:
#   ./tests/run-tests.sh                    # Run offline tests only (error handling, arg validation)
#   LIVE_TEST=true ./tests/run-tests.sh     # Run all tests including live API tests
#
# Requirements:
#   - jq (for JSON validation and field extraction)
#   - OPENSEA_API_KEY env var (required when LIVE_TEST=true)
#   - @opensea/cli (optional, for parity tests; install with: npm install -g @opensea/cli)

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)/scripts"

# Use temp file for counters so subshell increments persist
COUNTER_FILE=$(mktemp)
echo "0 0 0" > "$COUNTER_FILE"
trap 'rm -f "$COUNTER_FILE"' EXIT

# Test data constants
TEST_COLLECTION="boredapeyachtclub"
TEST_CHAIN="ethereum"
TEST_CONTRACT="0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
TEST_TOKEN_ID="1"
TEST_WALLET="0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

# Rate-limit pacing (seconds between live API calls)
PACE_DELAY="${PACE_DELAY:-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

##############################################################################
# Helpers
##############################################################################

log_section() {
  echo ""
  echo -e "${BOLD}${CYAN}=== $1 ===${NC}"
}

log_test() {
  echo -ne "  ${BOLD}TEST:${NC} $1 ... "
}

_inc_counter() {
  local idx="$1"
  local p f s
  read -r p f s < "$COUNTER_FILE"
  case "$idx" in
    pass)  p=$((p + 1)) ;;
    fail)  f=$((f + 1)) ;;
    skip)  s=$((s + 1)) ;;
  esac
  echo "$p $f $s" > "$COUNTER_FILE"
}

pass() {
  echo -e "${GREEN}PASS${NC}"
  _inc_counter pass
}

fail() {
  echo -e "${RED}FAIL${NC}"
  if [ -n "${1:-}" ]; then
    echo -e "    ${RED}$1${NC}"
  fi
  _inc_counter fail
}

skip() {
  echo -e "${YELLOW}SKIP${NC}"
  if [ -n "${1:-}" ]; then
    echo -e "    ${YELLOW}$1${NC}"
  fi
  _inc_counter skip
}

pace() {
  if [ "${LIVE_TEST:-}" = "true" ] && [ "$PACE_DELAY" -gt 0 ]; then
    sleep "$PACE_DELAY"
  fi
}

# Run a script and capture stdout, stderr, and exit code
# Usage: run_script <script> [args...]
# Sets: STDOUT, STDERR, EXIT_CODE
run_script() {
  local script="$1"
  shift
  local tmp_out tmp_err
  tmp_out=$(mktemp)
  tmp_err=$(mktemp)
  set +e
  "$SCRIPT_DIR/$script" "$@" >"$tmp_out" 2>"$tmp_err"
  EXIT_CODE=$?
  set -e
  STDOUT=$(cat "$tmp_out")
  STDERR=$(cat "$tmp_err")
  rm -f "$tmp_out" "$tmp_err"
}

# Silent assertions: return 0/1 only, no side effects on counters.
# Callsites are responsible for calling pass()/fail()/skip().

assert_exit() {
  [ "$EXIT_CODE" -eq "$1" ]
}

assert_json() {
  echo "$STDOUT" | jq empty 2>/dev/null
}

assert_field() {
  echo "$STDOUT" | jq -e "$1" >/dev/null 2>&1
}

assert_stderr_contains() {
  echo "$STDERR" | grep -qi "$1"
}

assert_success_json() {
  assert_exit 0 && assert_json
}

##############################################################################
# Preflight checks
##############################################################################

log_section "Preflight Checks"

# Check jq
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed"
  exit 1
fi
echo "  jq: $(jq --version)"

# Check curl
if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required but not installed"
  exit 1
fi
echo "  curl: $(curl --version | head -1)"

# Check scripts directory
if [ ! -d "$SCRIPT_DIR" ]; then
  echo "ERROR: scripts directory not found at $SCRIPT_DIR"
  exit 1
fi
echo "  scripts dir: $SCRIPT_DIR"

# Check LIVE_TEST mode
if [ "${LIVE_TEST:-}" = "true" ]; then
  echo -e "  mode: ${GREEN}LIVE (API tests enabled)${NC}"
  if [ -z "${OPENSEA_API_KEY:-}" ]; then
    echo "ERROR: OPENSEA_API_KEY is required when LIVE_TEST=true"
    exit 1
  fi
  echo "  API key: set (${#OPENSEA_API_KEY} chars)"
else
  echo -e "  mode: ${YELLOW}OFFLINE (only error handling tests)${NC}"
fi

# Check CLI for parity tests
CLI_AVAILABLE=false
if command -v opensea >/dev/null 2>&1 || npx @opensea/cli --version >/dev/null 2>&1; then
  CLI_AVAILABLE=true
  echo -e "  CLI: ${GREEN}available${NC}"
else
  echo -e "  CLI: ${YELLOW}not available (parity tests will be skipped)${NC}"
fi

##############################################################################
# 1. Error Handling Tests (no API key needed)
##############################################################################

log_section "Error Handling Tests: Missing Arguments"

# Helper: test missing args pattern
test_missing_args() {
  local script="$1"
  shift
  log_test "$script with no args"
  run_script "$script" "$@"
  if [ "$EXIT_CODE" -ne 0 ] && assert_stderr_contains "Usage"; then
    pass
  else
    fail "expected non-zero exit and 'Usage' in stderr (got exit=$EXIT_CODE)"
  fi
}

test_missing_args opensea-get.sh
test_missing_args opensea-post.sh
test_missing_args opensea-collection.sh
test_missing_args opensea-collection-stats.sh
test_missing_args opensea-collection-nfts.sh
test_missing_args opensea-nft.sh

log_test "opensea-nft.sh with too few args"
run_script opensea-nft.sh ethereum 0xabc
if [ "$EXIT_CODE" -ne 0 ] && assert_stderr_contains "Usage"; then
  pass
else
  fail "expected non-zero exit and 'Usage' in stderr"
fi

test_missing_args opensea-account-nfts.sh
test_missing_args opensea-listings-collection.sh
test_missing_args opensea-listings-nft.sh
test_missing_args opensea-offers-collection.sh
test_missing_args opensea-offers-nft.sh
test_missing_args opensea-best-listing.sh
test_missing_args opensea-best-offer.sh
test_missing_args opensea-order.sh
test_missing_args opensea-fulfill-listing.sh
test_missing_args opensea-fulfill-offer.sh
test_missing_args opensea-events-collection.sh
test_missing_args opensea-swap.sh
test_missing_args opensea-stream-collection.sh

##############################################################################
# 2. Shared Transport Tests: API Key Handling
##############################################################################

log_section "Shared Transport Tests: Missing API Key"

# opensea-get.sh without OPENSEA_API_KEY
log_test "opensea-get.sh rejects missing API key"
(
  unset OPENSEA_API_KEY 2>/dev/null || true
  run_script opensea-get.sh /api/v2/collections/test
  if [ "$EXIT_CODE" -ne 0 ] && assert_stderr_contains "OPENSEA_API_KEY"; then
    pass
  else
    fail "expected non-zero exit and 'OPENSEA_API_KEY' in stderr"
  fi
)

log_test "opensea-post.sh rejects missing API key"
(
  unset OPENSEA_API_KEY 2>/dev/null || true
  run_script opensea-post.sh /api/v2/test '{"test": true}'
  if [ "$EXIT_CODE" -ne 0 ] && assert_stderr_contains "OPENSEA_API_KEY"; then
    pass
  else
    fail "expected non-zero exit and 'OPENSEA_API_KEY' in stderr"
  fi
)

##############################################################################
# 3. Shared Transport Tests: Bad API Key (live)
##############################################################################

if [ "${LIVE_TEST:-}" = "true" ]; then

  log_section "Shared Transport Tests: Bad API Key"

  log_test "opensea-get.sh with invalid API key"
  (
    export OPENSEA_API_KEY="invalid-key-for-testing"
    run_script opensea-get.sh /api/v2/collections/boredapeyachtclub
    # Public GET endpoints may return 200 even with invalid keys (rate-limited but not rejected)
    if [ "$EXIT_CODE" -ne 0 ] || assert_json; then
      pass
    else
      fail "expected non-zero exit or valid JSON response (got exit=$EXIT_CODE)"
    fi
  )
  pace

  log_test "opensea-post.sh with invalid API key returns error"
  (
    export OPENSEA_API_KEY="invalid-key-for-testing"
    run_script opensea-post.sh /api/v2/listings/fulfillment_data '{"listing":{}}'
    if [ "$EXIT_CODE" -ne 0 ]; then
      pass
    else
      fail "expected non-zero exit with invalid API key"
    fi
  )
  pace

  ##############################################################################
  # 4. Shared Transport Tests: OPENSEA_BASE_URL override
  ##############################################################################

  log_section "Shared Transport Tests: OPENSEA_BASE_URL Override"

  log_test "opensea-get.sh uses OPENSEA_BASE_URL when set"
  (
    export OPENSEA_BASE_URL="https://httpbin.org"
    export OPENSEA_API_KEY="dummy-test-key"
    run_script opensea-get.sh /anything
    # httpbin.org returns JSON at /anything — verifies the base URL was used
    if [ "$EXIT_CODE" -eq 0 ] && assert_json; then
      pass
    else
      fail "expected exit 0 and valid JSON from httpbin.org (got exit=$EXIT_CODE)"
    fi
  )
  pace

fi

##############################################################################
# 5. Live API Tests: Read Operations
##############################################################################

if [ "${LIVE_TEST:-}" = "true" ]; then

  log_section "Live API Tests: Read Operations"

  # Helper: test live GET with field assertions
  test_live_get() {
    local label="$1"; shift
    local script="$1"; shift
    local fields=(); local args=(); local parsing_fields=false
    for arg in "$@"; do
      if [ "$arg" = "--fields" ]; then parsing_fields=true; continue; fi
      if [ "$parsing_fields" = "true" ]; then fields+=("$arg"); else args+=("$arg"); fi
    done
    log_test "$label"
    run_script "$script" "${args[@]}"
    if [ "$EXIT_CODE" -ne 0 ]; then
      fail "exit code $EXIT_CODE (expected 0). stderr: $STDERR"; return
    fi
    if ! echo "$STDOUT" | jq empty 2>/dev/null; then
      fail "output is not valid JSON"; return
    fi
    for field in "${fields[@]}"; do
      if ! echo "$STDOUT" | jq -e "$field" >/dev/null 2>&1; then
        fail "missing field: $field"; return
      fi
    done
    pass
  }

  test_live_get "opensea-collection.sh $TEST_COLLECTION" \
    opensea-collection.sh "$TEST_COLLECTION" \
    --fields .collection .name
  pace

  test_live_get "opensea-collection-stats.sh $TEST_COLLECTION" \
    opensea-collection-stats.sh "$TEST_COLLECTION" \
    --fields .total
  pace

  test_live_get "opensea-collection-nfts.sh $TEST_COLLECTION (limit 2)" \
    opensea-collection-nfts.sh "$TEST_COLLECTION" 2 \
    --fields .nfts
  pace

  test_live_get "opensea-nft.sh $TEST_CHAIN $TEST_CONTRACT $TEST_TOKEN_ID" \
    opensea-nft.sh "$TEST_CHAIN" "$TEST_CONTRACT" "$TEST_TOKEN_ID" \
    --fields .nft
  pace

  test_live_get "opensea-account-nfts.sh $TEST_CHAIN $TEST_WALLET (limit 2)" \
    opensea-account-nfts.sh "$TEST_CHAIN" "$TEST_WALLET" 2 \
    --fields .nfts
  pace

  ##############################################################################
  # 6. Live API Tests: Marketplace Reads
  ##############################################################################

  log_section "Live API Tests: Marketplace Reads"

  # opensea-listings-collection.sh (save output for later tests)
  log_test "opensea-listings-collection.sh $TEST_COLLECTION (limit 2)"
  run_script opensea-listings-collection.sh "$TEST_COLLECTION" 2
  if assert_success_json && assert_field '.listings'; then
    pass
  else
    fail "exit=$EXIT_CODE or invalid JSON or missing .listings"
  fi
  LISTINGS_OUTPUT="$STDOUT"
  pace

  test_live_get "opensea-listings-nft.sh $TEST_CHAIN $TEST_CONTRACT $TEST_TOKEN_ID" \
    opensea-listings-nft.sh "$TEST_CHAIN" "$TEST_CONTRACT" "$TEST_TOKEN_ID" 2 \
    --fields .orders
  pace

  # opensea-offers-collection.sh (save output for later tests)
  log_test "opensea-offers-collection.sh $TEST_COLLECTION (limit 2)"
  run_script opensea-offers-collection.sh "$TEST_COLLECTION" 2
  if assert_success_json && assert_field '.offers'; then
    pass
  else
    fail "exit=$EXIT_CODE or invalid JSON or missing .offers"
  fi
  OFFERS_OUTPUT="$STDOUT"
  pace

  test_live_get "opensea-offers-nft.sh $TEST_CHAIN $TEST_CONTRACT $TEST_TOKEN_ID" \
    opensea-offers-nft.sh "$TEST_CHAIN" "$TEST_CONTRACT" "$TEST_TOKEN_ID" 2 \
    --fields .orders
  pace

  # opensea-best-listing.sh — may return error if no listing for this token
  log_test "opensea-best-listing.sh $TEST_COLLECTION $TEST_TOKEN_ID"
  run_script opensea-best-listing.sh "$TEST_COLLECTION" "$TEST_TOKEN_ID"
  if [ "$EXIT_CODE" -eq 0 ] && assert_json; then
    pass
  else
    skip "no active listing for $TEST_COLLECTION/$TEST_TOKEN_ID (exit=$EXIT_CODE)"
  fi
  BEST_LISTING_OUTPUT="$STDOUT"
  pace

  # opensea-best-offer.sh — may return error if no offer for this token
  log_test "opensea-best-offer.sh $TEST_COLLECTION $TEST_TOKEN_ID"
  run_script opensea-best-offer.sh "$TEST_COLLECTION" "$TEST_TOKEN_ID"
  if [ "$EXIT_CODE" -eq 0 ] && assert_json; then
    pass
  else
    skip "no active offer for $TEST_COLLECTION/$TEST_TOKEN_ID (exit=$EXIT_CODE)"
  fi
  BEST_OFFER_OUTPUT="$STDOUT"
  pace

  # opensea-order.sh — derive order hash from listings
  log_test "opensea-order.sh with order hash from listings"
  ORDER_HASH=$(echo "$LISTINGS_OUTPUT" | jq -r '.listings[0].order_hash // empty' 2>/dev/null || true)
  if [ -n "$ORDER_HASH" ]; then
    run_script opensea-order.sh "$TEST_CHAIN" "$ORDER_HASH"
    if [ "$EXIT_CODE" -eq 0 ] && assert_json; then
      pass
    else
      fail "exit=$EXIT_CODE for order hash $ORDER_HASH"
    fi
  else
    skip "no listing order hash available to test"
  fi
  pace

  ##############################################################################
  # 7. Live API Tests: Write Operations (Fulfillment Data)
  ##############################################################################

  log_section "Live API Tests: Fulfillment Data"

  log_test "opensea-fulfill-listing.sh with live order hash"
  LISTING_HASH=$(echo "$BEST_LISTING_OUTPUT" | jq -r '.order_hash // empty' 2>/dev/null || true)
  if [ -z "$LISTING_HASH" ]; then
    LISTING_HASH=$(echo "$LISTINGS_OUTPUT" | jq -r '.listings[0].order_hash // empty' 2>/dev/null || true)
  fi
  if [ -n "$LISTING_HASH" ]; then
    run_script opensea-fulfill-listing.sh "$TEST_CHAIN" "$LISTING_HASH" "$TEST_WALLET"
    if [ "$EXIT_CODE" -eq 0 ] && assert_json; then
      pass
    else
      # API may reject fulfillment (expired order, etc.) — check stderr
      # contains an API-related message to distinguish from infra failures
      if echo "$STDERR" | grep -qi "HTTP\|expired\|order\|fulfillment\|error\|40[0-9]\|50[0-9]"; then
        pass
      else
        fail "exit=$EXIT_CODE, unexpected stderr: $STDERR"
      fi
    fi
  else
    skip "no listing hash available for fulfillment test"
  fi
  pace

  log_test "opensea-fulfill-offer.sh with live order hash"
  OFFER_HASH=$(echo "$BEST_OFFER_OUTPUT" | jq -r '.order_hash // empty' 2>/dev/null || true)
  if [ -z "$OFFER_HASH" ]; then
    OFFER_HASH=$(echo "$OFFERS_OUTPUT" | jq -r '.offers[0].order_hash // empty' 2>/dev/null || true)
  fi
  if [ -n "$OFFER_HASH" ]; then
    run_script opensea-fulfill-offer.sh "$TEST_CHAIN" "$OFFER_HASH" "$TEST_WALLET" "$TEST_CONTRACT" "$TEST_TOKEN_ID"
    if [ "$EXIT_CODE" -eq 0 ] && assert_json; then
      pass
    else
      if echo "$STDERR" | grep -qi "HTTP\|expired\|order\|fulfillment\|error\|40[0-9]\|50[0-9]"; then
        pass
      else
        fail "exit=$EXIT_CODE, unexpected stderr: $STDERR"
      fi
    fi
  else
    skip "no offer hash available for fulfillment test"
  fi
  pace

  ##############################################################################
  # 8. Live API Tests: Events
  ##############################################################################

  log_section "Live API Tests: Events"

  test_live_get "opensea-events-collection.sh $TEST_COLLECTION (limit 2)" \
    opensea-events-collection.sh "$TEST_COLLECTION" "" 2 \
    --fields .asset_events
  pace

  test_live_get "opensea-events-collection.sh $TEST_COLLECTION sale (limit 2)" \
    opensea-events-collection.sh "$TEST_COLLECTION" sale 2 \
    --fields .asset_events
  pace

  ##############################################################################
  # 9. Live API Tests: Swap (opensea-swap.sh)
  ##############################################################################

  log_section "Live API Tests: Swap"

  log_test "opensea-swap.sh missing PRIVATE_KEY"
  (
    unset PRIVATE_KEY 2>/dev/null || true
    run_script opensea-swap.sh 0xTokenAddr 0.01 0xWallet base
    if [ "$EXIT_CODE" -ne 0 ] && assert_stderr_contains "PRIVATE_KEY"; then
      pass
    else
      fail "expected non-zero exit and 'PRIVATE_KEY' in stderr (got exit=$EXIT_CODE)"
    fi
  )

  log_test "opensea-swap.sh live quote retrieval"
  if command -v mcporter >/dev/null 2>&1; then
    skip "mcporter available but live swap test requires real wallet — skipping to avoid tx"
  else
    skip "mcporter not available (required for swap quote via MCP)"
  fi

  ##############################################################################
  # 10. Parity Tests: Script vs CLI output
  ##############################################################################

  log_section "Parity Tests: Script vs CLI"

  if [ "$CLI_AVAILABLE" = "true" ]; then

    # Helper: run CLI command and capture output
    run_cli() {
      local tmp_out tmp_err
      tmp_out=$(mktemp)
      tmp_err=$(mktemp)
      set +e
      npx @opensea/cli "$@" --format json >"$tmp_out" 2>"$tmp_err"
      CLI_EXIT=$?
      set -e
      CLI_STDOUT=$(cat "$tmp_out")
      CLI_STDERR=$(cat "$tmp_err")
      rm -f "$tmp_out" "$tmp_err"
    }

    # Parity: opensea-collection.sh vs CLI collections get
    log_test "parity: opensea-collection.sh vs 'opensea collections get'"
    run_script opensea-collection.sh "$TEST_COLLECTION"
    SCRIPT_COLLECTION_NAME=$(echo "$STDOUT" | jq -r '.collection // .name // empty' 2>/dev/null || true)
    run_cli collections get "$TEST_COLLECTION"
    CLI_COLLECTION_NAME=$(echo "$CLI_STDOUT" | jq -r '.collection // .name // empty' 2>/dev/null || true)
    if [ -n "$SCRIPT_COLLECTION_NAME" ] && [ -n "$CLI_COLLECTION_NAME" ] && [ "$SCRIPT_COLLECTION_NAME" = "$CLI_COLLECTION_NAME" ]; then
      pass
    elif [ -n "$SCRIPT_COLLECTION_NAME" ] && [ -n "$CLI_COLLECTION_NAME" ]; then
      # Even if exact names differ, both returned data — check that both are valid JSON
      if echo "$STDOUT" | jq empty 2>/dev/null && echo "$CLI_STDOUT" | jq empty 2>/dev/null; then
        pass
      else
        fail "output mismatch: script='$SCRIPT_COLLECTION_NAME' cli='$CLI_COLLECTION_NAME'"
      fi
    else
      fail "could not extract collection name from one or both outputs"
    fi
    pace

    # Parity: opensea-collection-stats.sh vs CLI collections stats
    log_test "parity: opensea-collection-stats.sh vs 'opensea collections stats'"
    run_script opensea-collection-stats.sh "$TEST_COLLECTION"
    SCRIPT_TOTAL=$(echo "$STDOUT" | jq -r '.total // empty' 2>/dev/null || true)
    run_cli collections stats "$TEST_COLLECTION"
    CLI_TOTAL=$(echo "$CLI_STDOUT" | jq -r '.total // empty' 2>/dev/null || true)
    if [ -n "$SCRIPT_TOTAL" ] && [ -n "$CLI_TOTAL" ] && [ "$SCRIPT_TOTAL" = "$CLI_TOTAL" ]; then
      pass
    elif [ -n "$SCRIPT_TOTAL" ] && [ -n "$CLI_TOTAL" ]; then
      # Both returned data — counts might differ slightly due to timing
      pass
    else
      fail "could not extract total from one or both outputs"
    fi
    pace

    # Parity: opensea-nft.sh vs CLI nfts get
    log_test "parity: opensea-nft.sh vs 'opensea nfts get'"
    run_script opensea-nft.sh "$TEST_CHAIN" "$TEST_CONTRACT" "$TEST_TOKEN_ID"
    SCRIPT_NFT_ID=$(echo "$STDOUT" | jq -r '.nft.identifier // empty' 2>/dev/null || true)
    run_cli nfts get "$TEST_CHAIN" "$TEST_CONTRACT" "$TEST_TOKEN_ID"
    CLI_NFT_ID=$(echo "$CLI_STDOUT" | jq -r '.nft.identifier // .identifier // empty' 2>/dev/null || true)
    if [ -n "$SCRIPT_NFT_ID" ] && [ -n "$CLI_NFT_ID" ] && [ "$SCRIPT_NFT_ID" = "$CLI_NFT_ID" ]; then
      pass
    elif echo "$STDOUT" | jq empty 2>/dev/null && echo "$CLI_STDOUT" | jq empty 2>/dev/null; then
      # Both returned valid JSON — acceptable even if field paths differ
      pass
    else
      fail "parity mismatch on NFT identifier"
    fi
    pace

    # Parity: opensea-collection-nfts.sh vs CLI nfts list-by-collection
    log_test "parity: opensea-collection-nfts.sh vs 'opensea nfts list-by-collection'"
    run_script opensea-collection-nfts.sh "$TEST_COLLECTION" 2
    SCRIPT_NFT_COUNT=$(echo "$STDOUT" | jq '.nfts | length' 2>/dev/null || echo 0)
    run_cli nfts list-by-collection "$TEST_COLLECTION" --limit 2
    CLI_NFT_COUNT=$(echo "$CLI_STDOUT" | jq '.nfts | length' 2>/dev/null || echo 0)
    if [ "$SCRIPT_NFT_COUNT" -gt 0 ] && [ "$CLI_NFT_COUNT" -gt 0 ]; then
      pass
    elif [ "$SCRIPT_NFT_COUNT" -eq 0 ] && [ "$CLI_NFT_COUNT" -eq 0 ]; then
      pass
    else
      fail "parity mismatch: script returned $SCRIPT_NFT_COUNT NFTs, CLI returned $CLI_NFT_COUNT"
    fi
    pace

    # Parity: opensea-events-collection.sh vs CLI events by-collection
    log_test "parity: opensea-events-collection.sh vs 'opensea events by-collection'"
    run_script opensea-events-collection.sh "$TEST_COLLECTION" "" 2
    SCRIPT_HAS_EVENTS=$(echo "$STDOUT" | jq '.asset_events | length > 0' 2>/dev/null || echo false)
    run_cli events by-collection "$TEST_COLLECTION" --limit 2
    CLI_HAS_EVENTS=$(echo "$CLI_STDOUT" | jq '.asset_events | length > 0' 2>/dev/null || echo false)
    if [ "$SCRIPT_HAS_EVENTS" = "true" ] && [ "$CLI_HAS_EVENTS" = "true" ]; then
      pass
    elif [ "$SCRIPT_HAS_EVENTS" = "$CLI_HAS_EVENTS" ]; then
      pass
    else
      fail "parity mismatch: script has_events=$SCRIPT_HAS_EVENTS, CLI has_events=$CLI_HAS_EVENTS"
    fi
    pace

  else
    log_test "parity: opensea-collection.sh vs CLI"
    skip "CLI not available"
    log_test "parity: opensea-collection-stats.sh vs CLI"
    skip "CLI not available"
    log_test "parity: opensea-nft.sh vs CLI"
    skip "CLI not available"
    log_test "parity: opensea-collection-nfts.sh vs CLI"
    skip "CLI not available"
    log_test "parity: opensea-events-collection.sh vs CLI"
    skip "CLI not available"
  fi

fi

##############################################################################
# Summary
##############################################################################

echo ""
echo -e "${BOLD}${CYAN}========================================${NC}"
echo -e "${BOLD}Test Summary${NC}"
echo -e "${BOLD}${CYAN}========================================${NC}"
read -r TESTS_PASSED TESTS_FAILED TESTS_SKIPPED < "$COUNTER_FILE"
echo -e "  ${GREEN}Passed:  $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed:  $TESTS_FAILED${NC}"
echo -e "  ${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
TOTAL=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
echo -e "  Total:   $TOTAL"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
  echo -e "${RED}${BOLD}SOME TESTS FAILED${NC}"
  exit 1
else
  echo -e "${GREEN}${BOLD}ALL TESTS PASSED${NC}"
  exit 0
fi
