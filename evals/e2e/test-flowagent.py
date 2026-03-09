"""
FlowAgent E2E Test — tested on local platform

Steps:
1. Use existing Claude provider
2. Discover tools
3. Create poet agent (no tools)
4. Call and check mission
5. Create device inspector agent (with tools)
6. Call and check mission
7. Cleanup
"""
import json, requests, time

BASE = "http://localhost:4000"
r = requests.post(f"{BASE}/login", json={"username": "admin", "password": "admin"})
TOKEN = r.text.strip('"')
P = {"token": TOKEN}
H = {"Content-Type": "application/json"}

def api(method, path, body=None):
    resp = getattr(requests, method.lower())(f"{BASE}{path}", params=P, headers=H, json=body, timeout=60)
    try: return resp.json()
    except: return resp.text[:200] if resp.text else None

print("=" * 60)
print("FLOWAGENT E2E TEST")
print("=" * 60)

# 1. Find Claude provider
providers = api("GET", "/flowai/providers")
claude = next((p["name"] for p in providers if p.get("type") == "claude" and p.get("config", {}).get("hasApiKey")), None)
if not claude:
    print("ERROR: No Claude provider. Exiting.")
    exit(1)
print(f"Provider: {claude}")

# 2. Discover tools
api("POST", "/flowai/discover/tools")
tools = api("GET", "/flowai/tools")
print(f"Tools: {len(tools)}")

# 3. Create poet agent
print("\n--- Poet agent (no tools) ---")
api("POST", "/flowai/agents", {"details": {
    "name": "zztest-poet", "description": "haiku",
    "identity": {"agent_account": "admin", "agent_password": "admin"},
    "llm": {"provider": claude, "overrides": {"model": "claude-haiku-4-5-20251001"}},
    "messages": [
        {"role": "system", "content": "Write exactly one haiku. Nothing else."},
        {"role": "user", "content": "Write a haiku about firewalls."}
    ],
    "capabilities": {"toolset": [], "agents": [], "projects": []}
}})
api("POST", "/flowai/agents/zztest-poet/call", {"context": {}})
time.sleep(5)
for m in api("GET", "/flowai/missions"):
    if m.get("agent") == "zztest-poet":
        print(f"  Success: {m.get('success')}")
        print(f"  Haiku: {m.get('conclusion','?')}")
        break

# 4. Create device inspector
print("\n--- Device inspector (with tools) ---")
device_tool = next((t["identifier"] for t in tools if "getDevice" in t.get("identifier","") and t.get("active")), None)
if device_tool:
    print(f"  Tool: {device_tool}")
    api("POST", "/flowai/agents", {"details": {
        "name": "zztest-inspector", "description": "device check",
        "identity": {"agent_account": "admin", "agent_password": "admin"},
        "llm": {"provider": claude, "overrides": {"model": "claude-haiku-4-5-20251001"}},
        "messages": [
            {"role": "system", "content": "Inspect devices. Use tools. Be concise."},
            {"role": "user", "content": "Get details for IOS-CAT8KV-1. Report OS, IP, adapter."}
        ],
        "capabilities": {"toolset": [device_tool], "agents": [], "projects": []}
    }})
    api("POST", "/flowai/agents/zztest-inspector/call", {"context": {}})
    time.sleep(10)
    for m in api("GET", "/flowai/missions"):
        if m.get("agent") == "zztest-inspector":
            print(f"  Success: {m.get('success')}")
            print(f"  Conclusion: {m.get('conclusion','?')[:300]}")
            ts = m.get("toolStats", {})
            if ts: print(f"  Tool calls: {ts.get('totalCalls','?')} {ts.get('tools',{})}")
            break
else:
    print("  No getDevice tool, skipping")

# 5. Cleanup
print("\n--- Cleanup ---")
for name in ["zztest-poet", "zztest-inspector"]:
    api("DELETE", f"/flowai/agents/{name}")
for m in api("GET", "/flowai/missions"):
    if "zztest" in m.get("agent", ""):
        api("DELETE", f"/flowai/missions/{m['_id']}")
print("Done")
