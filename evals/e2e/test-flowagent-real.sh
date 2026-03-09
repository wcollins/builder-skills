#!/bin/bash
# FlowAgent E2E — Real operations: ServiceNow change + device backup + multi-tool
# Platform: localhost:4000

set -uo pipefail
BASE="http://localhost:4000"
PASSED=0
FAILED=0

assert_pass() { echo "    PASS: $1"; PASSED=$((PASSED+1)); }
assert_fail() { echo "    FAIL: $1"; FAILED=$((FAILED+1)); }

check_mission() {
  local agent_name="$1"
  curl -s -b /tmp/it-cookies "$BASE/flowai/missions" | python3 -c "
import json,sys
data = json.loads(sys.stdin.read(), strict=False)
for m in sorted(data, key=lambda x: x.get('start',''), reverse=True):
    if m.get('agent') == '${agent_name}':
        tools = m.get('toolStats', {})
        tc = tools.get('total_tool_calls', tools.get('totalCalls', 0))
        tn = tools.get('tools_used', list(tools.get('tools', {}).keys()))
        tok = m.get('tokenUsage', {}).get('input_tokens', 0)
        c = str(m.get('conclusion', '')).replace(chr(10),' ')[:300]
        print(f'success={m.get(\"success\", False)}')
        print(f'total_calls={tc}')
        print(f'tool_names={\",\".join(tn) if isinstance(tn,list) else tn}')
        print(f'unique_tools={len(tn) if isinstance(tn,list) else 0}')
        print(f'input_tokens={tok}')
        print(f'conclusion={c}')
        break
else:
    print('success=False')
    print('total_calls=0')
    print('tool_names=')
    print('unique_tools=0')
    print('input_tokens=0')
    print('conclusion=NO_MISSION')
" 2>/dev/null
}

reauth() {
  curl -s -c /tmp/it-cookies -X POST "$BASE/login" \
    -H "Content-Type: application/json" \
    -d '{"user":{"username":"admin","password":"admin"}}' > /dev/null
}

# --- Auth ---
echo "=== Authenticating ==="
reauth
echo "Done."

PROVIDER=$(curl -s -b /tmp/it-cookies "$BASE/flowai/providers" | python3 -c "
import json,sys
for p in json.load(sys.stdin):
    if p.get('type')=='claude' and p.get('config',{}).get('hasApiKey'): print(p['name']); break" 2>/dev/null)
echo "Provider: $PROVIDER"
[ -z "$PROVIDER" ] && echo "No Claude provider" && exit 1

for n in e2e-change-agent e2e-backup-agent e2e-ops-agent; do
  curl -s -b /tmp/it-cookies -X DELETE "$BASE/flowai/agents/$n" > /dev/null 2>&1
done
sleep 1

# ============================================================
# TEST 1: ServiceNow Change Request
# ============================================================
echo ""
echo "=== TEST 1: Create ServiceNow Change Request ==="

cat > /tmp/fa-agent1.json << EOF
{"details":{"name":"e2e-change-agent","description":"Creates ServiceNow change requests","identity":{"agent_account":"admin","agent_password":"admin"},"llm":{"provider":"${PROVIDER}","overrides":{"model":"claude-haiku-4-5-20251001"}},"messages":[{"role":"system","content":"You create change requests. Use createNormalChangeRequest. The change object needs short_description and description fields. Be concise."},{"role":"user","content":"Create a normal change request. short_description: E2E Test Maintenance. description: Automated test from skill evaluator."}],"capabilities":{"toolset":["ServiceNow//createNormalChangeRequest"],"agents":[],"projects":[]}}}
EOF

CREATE_ID=$(curl -s -b /tmp/it-cookies -X POST "$BASE/flowai/agents" \
  -H "Content-Type: application/json" -d @/tmp/fa-agent1.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -n "$CREATE_ID" ]; then assert_pass "Agent created ($CREATE_ID)"; else assert_fail "Agent creation"; fi

echo "  Calling agent..."
curl -s -b /tmp/it-cookies -X POST "$BASE/flowai/agents/e2e-change-agent/call" \
  -H "Content-Type: application/json" -d '{"context":{}}' --max-time 60 > /dev/null 2>&1
sleep 6
reauth

check_mission "e2e-change-agent" > /tmp/fa-r1.txt
T1_SUCCESS=$(grep 'success=' /tmp/fa-r1.txt | head -1 | cut -d= -f2)
T1_CALLS=$(grep 'total_calls=' /tmp/fa-r1.txt | cut -d= -f2)
T1_TOOLS=$(grep 'tool_names=' /tmp/fa-r1.txt | cut -d= -f2)
T1_CONCLUSION=$(grep 'conclusion=' /tmp/fa-r1.txt | cut -d= -f2-)

if [ "$T1_SUCCESS" = "True" ]; then assert_pass "Mission succeeded"; else assert_fail "Mission failed"; fi
if [ "${T1_CALLS:-0}" -gt 0 ] 2>/dev/null; then assert_pass "Made $T1_CALLS tool call(s)"; else assert_fail "No tool calls"; fi
if echo "$T1_TOOLS" | grep -qi "createNormalChangeRequest"; then assert_pass "Used createNormalChangeRequest"; else assert_fail "Wrong tool: $T1_TOOLS"; fi
echo "  Result: ${T1_CONCLUSION:0:200}"

# ============================================================
# TEST 2: Device Config Backup
# ============================================================
echo ""
echo "=== TEST 2: Device Config Backup ==="

cat > /tmp/fa-agent2.json << EOF
{"details":{"name":"e2e-backup-agent","description":"Gets device config","identity":{"agent_account":"admin","agent_password":"admin"},"llm":{"provider":"${PROVIDER}","overrides":{"model":"claude-haiku-4-5-20251001"}},"messages":[{"role":"system","content":"You retrieve device configurations. Use getConfig with deviceName parameter. Report what you find concisely."},{"role":"user","content":"Get the running configuration for device CPE-1. Report the first few lines."}],"capabilities":{"toolset":["AutomationGateway//getConfig"],"agents":[],"projects":[]}}}
EOF

reauth
CREATE_ID2=$(curl -s -b /tmp/it-cookies -X POST "$BASE/flowai/agents" \
  -H "Content-Type: application/json" -d @/tmp/fa-agent2.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -n "$CREATE_ID2" ]; then assert_pass "Backup agent created"; else assert_fail "Backup agent creation"; fi

echo "  Calling agent..."
curl -s -b /tmp/it-cookies -X POST "$BASE/flowai/agents/e2e-backup-agent/call" \
  -H "Content-Type: application/json" -d '{"context":{}}' --max-time 60 > /dev/null 2>&1
sleep 6
reauth

check_mission "e2e-backup-agent" > /tmp/fa-r2.txt
T2_SUCCESS=$(grep 'success=' /tmp/fa-r2.txt | head -1 | cut -d= -f2)
T2_CALLS=$(grep 'total_calls=' /tmp/fa-r2.txt | cut -d= -f2)
T2_TOOLS=$(grep 'tool_names=' /tmp/fa-r2.txt | cut -d= -f2)
T2_CONCLUSION=$(grep 'conclusion=' /tmp/fa-r2.txt | cut -d= -f2-)

if [ "$T2_SUCCESS" = "True" ]; then assert_pass "Mission succeeded"; else assert_fail "Mission failed"; fi
if [ "${T2_CALLS:-0}" -gt 0 ] 2>/dev/null; then assert_pass "Made $T2_CALLS tool call(s)"; else assert_fail "No tool calls"; fi
if echo "$T2_TOOLS" | grep -qi "getConfig"; then assert_pass "Used getConfig"; else assert_fail "Wrong tool: $T2_TOOLS"; fi
echo "  Result: ${T2_CONCLUSION:0:200}"

# ============================================================
# TEST 3: Multi-Tool (Change + Backup in one mission)
# ============================================================
echo ""
echo "=== TEST 3: Multi-Tool Agent (Change + Backup) ==="

cat > /tmp/fa-agent3.json << EOF
{"details":{"name":"e2e-ops-agent","description":"Multi-tool ops","identity":{"agent_account":"admin","agent_password":"admin"},"llm":{"provider":"${PROVIDER}","overrides":{"model":"claude-haiku-4-5-20251001"}},"messages":[{"role":"system","content":"You are an ops agent. Complete all tasks. Use createNormalChangeRequest for tickets (change object needs short_description and description). Use getConfig for device configs (needs deviceName). Be concise."},{"role":"user","content":"Do two things: 1) Create a change request with short_description E2E Multi-Tool and description Testing multi-tool. 2) Get config for device CPE-1. Report both."}],"capabilities":{"toolset":["ServiceNow//createNormalChangeRequest","AutomationGateway//getConfig"],"agents":[],"projects":[]}}}
EOF

reauth
CREATE_ID3=$(curl -s -b /tmp/it-cookies -X POST "$BASE/flowai/agents" \
  -H "Content-Type: application/json" -d @/tmp/fa-agent3.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -n "$CREATE_ID3" ]; then assert_pass "Multi-tool agent created"; else assert_fail "Multi-tool agent creation"; fi

echo "  Calling agent (multi-tool, may take 30-60s)..."
curl -s -b /tmp/it-cookies -X POST "$BASE/flowai/agents/e2e-ops-agent/call" \
  -H "Content-Type: application/json" -d '{"context":{}}' --max-time 90 > /dev/null 2>&1
sleep 10
reauth

check_mission "e2e-ops-agent" > /tmp/fa-r3.txt
T3_SUCCESS=$(grep 'success=' /tmp/fa-r3.txt | head -1 | cut -d= -f2)
T3_CALLS=$(grep 'total_calls=' /tmp/fa-r3.txt | cut -d= -f2)
T3_UNIQUE=$(grep 'unique_tools=' /tmp/fa-r3.txt | cut -d= -f2)
T3_TOOLS=$(grep 'tool_names=' /tmp/fa-r3.txt | cut -d= -f2)
T3_CONCLUSION=$(grep 'conclusion=' /tmp/fa-r3.txt | cut -d= -f2-)

if [ "$T3_SUCCESS" = "True" ]; then assert_pass "Multi-tool mission succeeded"; else assert_fail "Multi-tool mission failed"; fi
if [ "${T3_CALLS:-0}" -gt 1 ] 2>/dev/null; then assert_pass "Made $T3_CALLS tool calls"; else assert_fail "Expected >1 calls (got ${T3_CALLS:-0})"; fi
if [ "${T3_UNIQUE:-0}" -ge 2 ] 2>/dev/null; then assert_pass "Used $T3_UNIQUE different tools"; else assert_fail "Expected 2+ tools (got ${T3_UNIQUE:-0}: $T3_TOOLS)"; fi
echo "  Result: ${T3_CONCLUSION:0:300}"

# ============================================================
# CLEANUP
# ============================================================
echo ""
echo "=== Cleanup ==="
reauth
for n in e2e-change-agent e2e-backup-agent e2e-ops-agent; do
  curl -s -b /tmp/it-cookies -X DELETE "$BASE/flowai/agents/$n" > /dev/null 2>&1
done
rm -f /tmp/fa-agent*.json /tmp/fa-r*.txt
echo "Done."

echo ""
echo "============================================"
echo "  FLOWAGENT REAL E2E RESULTS"
echo "============================================"
echo "  PASSED: $PASSED"
echo "  FAILED: $FAILED"
echo "  TOTAL:  $((PASSED + FAILED))"
echo "============================================"
