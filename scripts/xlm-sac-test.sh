#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# xlm-sac-test.sh — Integration test: native XLM stream via the SAC on Stellar Testnet
#
# Flow:
#   create XLM stream (employer → employee) → wait → withdraw
#   → verify employee XLM balance increased → cancel stream
#
# Usage:
#   export STREAM_CONTRACT_ID=<deployed stream contract id>
#   export EMPLOYER_KEY=<funded key name>   # e.g. from `stellar keys generate`
#   export EMPLOYEE_KEY=<funded key name>
#   ./scripts/xlm-sac-test.sh
#
# Both accounts must be funded (e.g. via Friendbot). Exits non-zero on failure.

set -euo pipefail

NETWORK="testnet"
STREAM="${STREAM_CONTRACT_ID:?Error: STREAM_CONTRACT_ID must be set}"
EMPLOYER_KEY="${EMPLOYER_KEY:?Error: EMPLOYER_KEY must be set}"
EMPLOYEE_KEY="${EMPLOYEE_KEY:?Error: EMPLOYEE_KEY must be set}"

DEPOSIT=10000000   # 1 XLM in stroops
RATE_PER_SECOND=10000
WAIT_SECONDS=30

log() { echo "[xlm-sac] $*"; }
fail() { echo "[xlm-sac] FAIL: $*" >&2; exit 1; }
strip() { tr -d '"'; }

EMPLOYER=$(stellar keys address "$EMPLOYER_KEY")
EMPLOYEE=$(stellar keys address "$EMPLOYEE_KEY")
XLM_SAC=$(stellar contract id asset --asset native --network "$NETWORK")
log "XLM SAC: $XLM_SAC"

balance() {
  stellar contract invoke --id "$XLM_SAC" --source "$EMPLOYEE_KEY" --network "$NETWORK" \
    -- balance --id "$1" | strip
}

BEFORE=$(balance "$EMPLOYEE")
log "Employee XLM balance before: $BEFORE"

STREAM_ID=$(stellar contract invoke --id "$STREAM" --source "$EMPLOYER_KEY" --network "$NETWORK" \
  -- create_stream \
    --employer "$EMPLOYER" \
    --employee "$EMPLOYEE" \
    --token_address "$XLM_SAC" \
    --deposit "$DEPOSIT" \
    --rate_per_second "$RATE_PER_SECOND" \
    --stop_time 0 | strip)
[[ -n "$STREAM_ID" ]] || fail "create_stream returned no ID"
log "Created XLM stream $STREAM_ID"

log "Waiting ${WAIT_SECONDS}s for accrual..."
sleep "$WAIT_SECONDS"

WITHDRAWN=$(stellar contract invoke --id "$STREAM" --source "$EMPLOYEE_KEY" --network "$NETWORK" \
  -- withdraw --employee "$EMPLOYEE" --stream_id "$STREAM_ID" | strip)
(( WITHDRAWN > 0 )) || fail "withdraw returned $WITHDRAWN"
log "Withdrew $WITHDRAWN stroops"

AFTER=$(balance "$EMPLOYEE")
log "Employee XLM balance after: $AFTER"
# Employee pays the withdraw tx fee in XLM, so allow for it.
(( AFTER > BEFORE )) || fail "employee balance did not increase ($BEFORE -> $AFTER)"

stellar contract invoke --id "$STREAM" --source "$EMPLOYER_KEY" --network "$NETWORK" \
  -- cancel_stream --employer "$EMPLOYER" --stream_id "$STREAM_ID" >/dev/null
log "Cancelled stream $STREAM_ID"

log "PASS"
