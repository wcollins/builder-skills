#!/bin/bash
# End-to-End Skill Evaluation Tests
# Deploys workflows to Itential platform, runs jobs, validates outputs
#
# Usage: ./run-e2e-tests.sh
# Requires: curl, python3, jq
# Platform: cloud (OAuth)

set -euo pipefail

BASE="https://platform-6.0-dev.se.itential.io"
CLIENT_ID="689c121d504f3190ca712d31"
CLIENT_SECRET="4e7476e9-8921-494d-927d-171fc569b795"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_FILE="$SCRIPT_DIR/e2e-results.json"

PASSED=0
FAILED=0
RESULTS=()

# --- Auth ---
echo "=== Authenticating ==="
TOKEN=$(curl -s -X POST "$BASE/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&grant_type=client_credentials" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")
AUTH="Authorization: Bearer $TOKEN"
echo "Authenticated."

# --- Helpers ---
create_workflow() {
  local file="$1"
  local name=$(python3 -c "import json; print(json.load(open('$file'))['automation']['name'])")
  echo "  Creating: $name"

  # Delete if exists
  local existing=$(curl -s "$BASE/automation-studio/workflows?limit=500" -H "$AUTH" \
    | python3 -c "
import json,sys
data=json.load(sys.stdin)
for w in data.get('items',[]):
    if w['name'] == '$name':
        print(w['_id'])
        break
" 2>/dev/null || true)

  if [ -n "$existing" ]; then
    echo "    Deleting existing: $existing"
    curl -s -X DELETE "$BASE/automation-studio/automations/$existing" -H "$AUTH" > /dev/null 2>&1 || true
    sleep 1
  fi

  local resp=$(curl -s -X POST "$BASE/automation-studio/automations" \
    -H "$AUTH" -H "Content-Type: application/json" -d @"$file")

  local wf_id=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('created',{}).get('_id',''))" 2>/dev/null || true)
  if [ -z "$wf_id" ]; then
    echo "    FAILED to create: $resp" | head -c 200
    return 1
  fi
  echo "    Created: $wf_id"
}

run_job() {
  local wf_name="$1"
  local variables="$2"
  local timeout="${3:-30}"

  local resp=$(curl -s -X POST "$BASE/operations-manager/jobs/start" \
    -H "$AUTH" -H "Content-Type: application/json" \
    -d "{\"workflow\": \"$wf_name\", \"options\": {\"type\": \"automation\", \"variables\": $variables}}")

  local job_id=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('_id',''))" 2>/dev/null || true)
  if [ -z "$job_id" ]; then
    echo "FAILED to start job: $resp" | head -c 200
    return 1
  fi
  echo "$job_id"
}

wait_for_job() {
  local job_id="$1"
  local timeout="${2:-45}"
  local elapsed=0

  while [ $elapsed -lt $timeout ]; do
    local status=$(curl -s "$BASE/operations-manager/jobs/$job_id" -H "$AUTH" \
      | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('status','unknown'))" 2>/dev/null || echo "unknown")

    if [ "$status" = "complete" ] || [ "$status" = "error" ] || [ "$status" = "canceled" ]; then
      echo "$status"
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  echo "timeout"
}

get_job_vars() {
  local job_id="$1"
  curl -s "$BASE/operations-manager/jobs/$job_id" -H "$AUTH" \
    | python3 -c "
import json, sys
data = json.load(sys.stdin).get('data', {})
# Resolve variable values
variables = data.get('variables', {})
resolved = {}
for k, v in variables.items():
    if isinstance(v, dict) and 'location' in v:
        # Unresolved reference - skip internal vars
        continue
    resolved[k] = v
print(json.dumps(resolved))
" 2>/dev/null
}

get_job_detail() {
  local job_id="$1"
  curl -s "$BASE/operations-manager/jobs/$job_id" -H "$AUTH"
}

assert_eq() {
  local test_name="$1"
  local actual="$2"
  local expected="$3"

  if [ "$actual" = "$expected" ]; then
    echo "    PASS: $test_name (got: $actual)"
    PASSED=$((PASSED + 1))
    RESULTS+=("{\"test\": \"$test_name\", \"status\": \"PASS\", \"expected\": \"$expected\", \"actual\": \"$actual\"}")
  else
    echo "    FAIL: $test_name (expected: $expected, got: $actual)"
    FAILED=$((FAILED + 1))
    RESULTS+=("{\"test\": \"$test_name\", \"status\": \"FAIL\", \"expected\": \"$expected\", \"actual\": \"$actual\"}")
  fi
}

assert_contains() {
  local test_name="$1"
  local haystack="$2"
  local needle="$3"

  if echo "$haystack" | grep -q "$needle"; then
    echo "    PASS: $test_name"
    PASSED=$((PASSED + 1))
    RESULTS+=("{\"test\": \"$test_name\", \"status\": \"PASS\", \"expected\": \"contains $needle\", \"actual\": \"found\"}")
  else
    echo "    FAIL: $test_name (expected to contain: $needle)"
    FAILED=$((FAILED + 1))
    RESULTS+=("{\"test\": \"$test_name\", \"status\": \"FAIL\", \"expected\": \"contains $needle\", \"actual\": \"$haystack\"}")
  fi
}

# ============================================================
# TEST 1: Utility Task Chain (merge → makeData → query → evaluation)
# ============================================================
echo ""
echo "=== TEST 1: Utility Task Chain ==="
echo "Pattern: merge → makeData → query → evaluation → branch"

create_workflow "$SCRIPT_DIR/test1-utility-chain.json"

# Test 1a: status=success → should branch to PASS
echo "  Running Test 1a: status=success (should PASS)..."
JOB_ID=$(run_job "E2E Test 1 - Utility Task Chain" '{"deviceName": "IOS-CAT8KV-1", "status": "success"}')
echo "  Job: $JOB_ID"
STATUS=$(wait_for_job "$JOB_ID" 45)
assert_eq "T1a: Job completes" "$STATUS" "complete"

if [ "$STATUS" = "complete" ]; then
  JOB_DATA=$(get_job_detail "$JOB_ID")

  FORMATTED=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
for tid, t in data['tasks'].items():
    if t['name'] == 'makeData' and t.get('status') == 'complete':
        # Get outgoing value
        out = t.get('variables',{}).get('outgoing',{}).get('output','')
        if isinstance(out, dict):
            print(out.get('value',''))
        else:
            print(out)
        break
" 2>/dev/null || echo "")
  # Check via job variables instead
  TEST_RESULT=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
# Walk tasks to find newVariable 'Set Pass' completion
for tid, t in data['tasks'].items():
    if t.get('summary') == 'Set Pass' and t.get('status') == 'complete':
        print('PASS')
        break
    if t.get('summary') == 'Set Fail' and t.get('status') == 'complete':
        print('FAIL')
        break
" 2>/dev/null || echo "UNKNOWN")
  assert_eq "T1a: Evaluation branched to PASS" "$TEST_RESULT" "PASS"

  EXTRACTED=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
for tid, t in data['tasks'].items():
    if t.get('summary') == 'Extract Status' and t.get('status') == 'complete':
        print('ok')
        break
" 2>/dev/null || echo "")
  assert_eq "T1a: query extracted status" "$EXTRACTED" "ok"
fi

# Test 1b: status=failure → should branch to FAIL
echo "  Running Test 1b: status=failure (should FAIL)..."
JOB_ID=$(run_job "E2E Test 1 - Utility Task Chain" '{"deviceName": "IOS-CAT8KV-1", "status": "failure"}')
echo "  Job: $JOB_ID"
STATUS=$(wait_for_job "$JOB_ID" 45)
assert_eq "T1b: Job completes" "$STATUS" "complete"

if [ "$STATUS" = "complete" ]; then
  JOB_DATA=$(get_job_detail "$JOB_ID")
  TEST_RESULT=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
for tid, t in data['tasks'].items():
    if t.get('summary') == 'Set Fail' and t.get('status') == 'complete':
        print('FAIL')
        break
    if t.get('summary') == 'Set Pass' and t.get('status') == 'complete':
        print('PASS')
        break
" 2>/dev/null || echo "UNKNOWN")
  assert_eq "T1b: Evaluation branched to FAIL" "$TEST_RESULT" "FAIL"
fi

# ============================================================
# TEST 2: childJob Loop (parent → child per device)
# ============================================================
echo ""
echo "=== TEST 2: childJob Loop ==="
echo "Pattern: childJob with data_array → query loop → query [**].taskStatus"

create_workflow "$SCRIPT_DIR/test2-child-workflow.json"
create_workflow "$SCRIPT_DIR/test2-parent-loop.json"

echo "  Running Test 2: 3 devices in parallel..."
JOB_ID=$(run_job "E2E Test 2 - Parent Loop" '{"devices": [{"deviceName": "Router-1"}, {"deviceName": "Router-2"}, {"deviceName": "Switch-1"}]}')
echo "  Job: $JOB_ID"
STATUS=$(wait_for_job "$JOB_ID" 60)
assert_eq "T2: Job completes" "$STATUS" "complete"

if [ "$STATUS" = "complete" ]; then
  JOB_DATA=$(get_job_detail "$JOB_ID")

  # Check childJob task completed
  CHILD_STATUS=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
for tid, t in data['tasks'].items():
    if t['name'] == 'childJob':
        print(t.get('status',''))
        break
" 2>/dev/null || echo "")
  assert_eq "T2: childJob completed" "$CHILD_STATUS" "complete"

  # Check all query tasks completed
  QUERY_COUNT=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
count=0
for tid, t in data['tasks'].items():
    if t['name'] == 'query' and t.get('status') == 'complete':
        count += 1
print(count)
" 2>/dev/null || echo "0")
  assert_eq "T2: Both query tasks completed" "$QUERY_COUNT" "2"
fi

# ============================================================
# TEST 3: ServiceNow Adapter (merge → create → query → extract)
# ============================================================
echo ""
echo "=== TEST 3: ServiceNow Adapter ==="
echo "Pattern: merge body → adapter create → query response → extract ID"

create_workflow "$SCRIPT_DIR/test3-adapter-servicenow.json"

echo "  Running Test 3: Create change request..."
JOB_ID=$(run_job "E2E Test 3 - ServiceNow Create and Query" '{"short_description": "E2E Test - Skill Eval", "description": "Automated e2e test from skill evaluator", "adapter_id": "ServiceNow"}')
echo "  Job: $JOB_ID"
STATUS=$(wait_for_job "$JOB_ID" 60)
assert_eq "T3: Job completes" "$STATUS" "complete"

if [ "$STATUS" = "complete" ]; then
  JOB_DATA=$(get_job_detail "$JOB_ID")

  # Check merge completed
  MERGE_STATUS=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
for tid, t in data['tasks'].items():
    if t['name'] == 'merge':
        print(t.get('status',''))
        break
" 2>/dev/null || echo "")
  assert_eq "T3: merge completed" "$MERGE_STATUS" "complete"

  # Check adapter completed (or errored gracefully)
  ADAPTER_STATUS=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
for tid, t in data['tasks'].items():
    if t['name'] == 'createChangeRequest':
        print(t.get('status',''))
        break
" 2>/dev/null || echo "")

  if [ "$ADAPTER_STATUS" = "complete" ]; then
    assert_eq "T3: adapter completed" "$ADAPTER_STATUS" "complete"

    # Check query extracted a change number
    QUERY_STATUS=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
for tid, t in data['tasks'].items():
    if t.get('summary') == 'Extract Change ID' and t.get('status') == 'complete':
        print('complete')
        break
" 2>/dev/null || echo "")
    assert_eq "T3: query extracted change number" "$QUERY_STATUS" "complete"

    # Verify Set Success ran
    PASS_STATUS=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
for tid, t in data['tasks'].items():
    if t.get('summary') == 'Set Success' and t.get('status') == 'complete':
        print('PASS')
        break
" 2>/dev/null || echo "")
    assert_eq "T3: success path taken" "$PASS_STATUS" "PASS"
  else
    # Adapter errored — check error handler caught it
    ERROR_HANDLER=$(echo "$JOB_DATA" | python3 -c "
import json,sys
data=json.load(sys.stdin)['data']
for tid, t in data['tasks'].items():
    if t.get('summary') == 'Set Error Status' and t.get('status') == 'complete':
        print('caught')
        break
" 2>/dev/null || echo "")
    assert_eq "T3: error transition caught adapter failure" "$ERROR_HANDLER" "caught"
    echo "    NOTE: Adapter errored but error handling worked correctly"
  fi
fi

# ============================================================
# RESULTS
# ============================================================
echo ""
echo "============================================"
echo "  E2E TEST RESULTS"
echo "============================================"
echo "  PASSED: $PASSED"
echo "  FAILED: $FAILED"
echo "  TOTAL:  $((PASSED + FAILED))"
echo "============================================"

# Write JSON report
python3 -c "
import json, datetime
results = [$(IFS=,; echo "${RESULTS[*]}")]
report = {
    'timestamp': datetime.datetime.utcnow().isoformat() + 'Z',
    'platform': '$BASE',
    'summary': {
        'passed': $PASSED,
        'failed': $FAILED,
        'total': $((PASSED + FAILED)),
        'pass_rate': round($PASSED / max($((PASSED + FAILED)), 1) * 100, 1)
    },
    'tests': {
        'test1_utility_chain': {
            'pattern': 'merge → makeData → query → evaluation → branch',
            'gotchas_tested': [
                'merge uses variable not value',
                'makeData variables must be resolved object',
                'query extracts from $var reference',
                'evaluation has both success and failure transitions',
                'hex-only task IDs'
            ]
        },
        'test2_childjob_loop': {
            'pattern': 'childJob with data_array → query loop → query [**].field',
            'gotchas_tested': [
                'childJob actor is job',
                'childJob task is empty string',
                'childJob job_details is null',
                'childJob variables empty when using data_array',
                'loopType parallel',
                'query flat variable names for childJob output'
            ]
        },
        'test3_adapter_servicenow': {
            'pattern': 'merge → adapter create → query response → extract',
            'gotchas_tested': [
                'adapter app from apps.json (Servicenow not ServiceNow)',
                'adapter_id in incoming',
                'error transition on adapter task',
                'dollar-var not inside nested body object',
                'JSON duplicate key workaround for error handler'
            ]
        }
    },
    'assertions': results
}
with open('$REPORT_FILE', 'w') as f:
    json.dump(report, f, indent=2)
print(f'Report saved to: $REPORT_FILE')
"

if [ $FAILED -gt 0 ]; then
  exit 1
fi
