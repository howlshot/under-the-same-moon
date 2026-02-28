# Godot MCP Connection Runbook (Port 6505)

## Verified Working Setup
- Project: `/Users/david/under-the-same-moon`
- Plugin URL: `ws://127.0.0.1:6505` (from `addons/godot_mcp/mcp_client.gd`)
- Server: `godot-mcp-server v0.2.0`
- Confirmation log lines:
  - Godot: `[MCP] Connected to server`
  - Server: `Godot connected`
  - Server: `Godot project: /Users/david/under-the-same-moon/`

## Root Cause Seen In This Incident
- Godot was launched inside a restricted sandbox where localhost TCP connect is blocked.
- Symptom in Godot logs: `Connection to remote host failed!`
- Symptom when probing localhost from sandbox: `Operation not permitted`
- Secondary failure mode: if the MCP server process used by Codex tools is killed manually, Godot MCP tool calls can fail with `Transport closed`.
- Additional failure mode (confirmed): Codex starts `godot-mcp-server`, but port `6505` is already occupied at session init. Server logs:
  - `listen EADDRINUSE: address already in use :::6505`
  - `Continuing in mock-only mode`
  In this state, `mcp__godot__*` calls return mock data even if Godot connects to a different bridge process.

## Reliable Recovery Steps
1. Stop any stale listener on port `6505`.
2. Start the websocket bridge first:
```bash
npx --yes --offline godot-mcp-server --host 127.0.0.1 --port 6505
```
3. Start Godot editor for this project:
```bash
godot --headless --editor --path /Users/david/under-the-same-moon
```
4. Wait for logs:
  - Godot: `[MCP] Connected to server`
  - Server: `Godot connected`

## Automated Recovery (Recommended First)
Use the project helper script:
```bash
scripts/dev/fix_godot_mcp.sh
```

What it does:
- Kills known stale headless Godot runners (`godot --headless --path . --scene res://main.tscn`).
- If multiple editor processes exist for this project, keeps only the newest one.
- Prints port `6505` sockets and remaining Godot/MCP processes.
- Returns:
  - `0` with `PASS` when both `LISTEN` and `ESTABLISHED` are present on port `6505`.
  - `1` with `WARN` when MCP is not fully connected.

If the script returns `WARN`, continue with the manual sections below (`Transport closed` / `mock mode`).

## If Codex Godot Tools Still Show `Transport closed`
1. Keep the two processes above running.
2. Restart the Codex session/agent so MCP transport re-initializes.
3. Re-check with `get_godot_status` and confirm:
  - `connected = true`
  - `project_path = /Users/david/under-the-same-moon`

## If Codex Godot Tools Show Mock Mode After Startup
1. Check Codex log for startup bind failure:
```bash
rg -n "EADDRINUSE|mock-only mode|Failed to start WebSocket server" ~/.codex/log/codex-tui.log | tail -n 20
```
2. If present, find stuck MCP processes:
```bash
ps aux | rg -i 'godot-mcp-server|npm exec godot-mcp-server' | rg -v rg
```
3. Kill the stuck MCP process pair (example PIDs):
```bash
kill <node_pid> <npm_pid>
```
4. Important behavior:
  - The current Codex thread may then report `Transport closed` and not auto-recover.
  - Open a new Codex chat/session in the same window (no full app restart required). The new session will spawn a fresh MCP server and should connect normally if port `6505` is free.

## Diagnostics Checklist
- Port listener:
```bash
lsof -nP -iTCP:6505 -sTCP:LISTEN
```
- Plugin enabled:
  - `project.godot` contains:
    - `enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")`
- Plugin target URL:
  - `addons/godot_mcp/mcp_client.gd` contains:
    - `const DEFAULT_URL := "ws://127.0.0.1:6505"`

## Notes
- Launch server before Godot to avoid first-attempt race/failure.
- Do not kill Codex-managed MCP processes unless you intend to restart the session immediately after.
- Prefer `scripts/dev/fix_godot_mcp.sh` before manual process cleanup.
