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

## If Codex Godot Tools Still Show `Transport closed`
1. Keep the two processes above running.
2. Restart the Codex session/agent so MCP transport re-initializes.
3. Re-check with `get_godot_status` and confirm:
  - `connected = true`
  - `project_path = /Users/david/under-the-same-moon`

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
