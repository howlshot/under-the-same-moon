#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="/Users/david/under-the-same-moon"
PORT="6505"

echo "== Godot MCP cleanup =="
echo "Project: ${PROJECT_PATH}"
echo "Port: ${PORT}"

find_pids() {
  local pattern="$1"
  ps aux | rg -i "$pattern" | rg -v rg | awk '{print $2}' || true
}

collect_pids() {
  local pattern="$1"
  local out=()
  while IFS= read -r pid; do
    [ -n "$pid" ] && out+=("$pid")
  done < <(find_pids "$pattern")
  printf '%s\n' "${out[@]:-}"
}

kill_pids() {
  local reason="$1"
  shift
  local pids=("$@")
  if [ "${#pids[@]}" -eq 0 ]; then
    return 0
  fi
  echo "Killing ${reason}: ${pids[*]}"
  kill "${pids[@]}" 2>/dev/null || true
}

# Kill known stale headless runners that often linger from test/play loops.
stale_headless=()
while IFS= read -r pid; do
  [ -n "$pid" ] && stale_headless+=("$pid")
done < <(collect_pids 'godot --headless --path \. --scene res://main\.tscn')
if [ "${#stale_headless[@]}" -gt 0 ]; then
  kill_pids "stale headless Godot runners" "${stale_headless[@]}"
fi

# Keep only the newest editor process for this project.
editor_pids=()
while IFS= read -r pid; do
  [ -n "$pid" ] && editor_pids+=("$pid")
done < <(collect_pids "godot --path ${PROJECT_PATH} --editor")
if [ "${#editor_pids[@]}" -gt 1 ]; then
  newest_pid="${editor_pids[-1]}"
  stale_editor=()
  for pid in "${editor_pids[@]}"; do
    if [ "$pid" != "$newest_pid" ]; then
      stale_editor+=("$pid")
    fi
  done
  if [ "${#stale_editor[@]}" -gt 0 ]; then
    kill_pids "stale Godot editor processes" "${stale_editor[@]}"
  fi
fi

sleep 1

echo
echo "== Port ${PORT} sockets =="
lsof -nP -iTCP:${PORT} || true

echo
echo "== Remaining Godot/MCP processes =="
ps aux | rg -i "[g]odot|godot-mcp-server|npm exec godot-mcp-server" || true

echo
echo "== Health summary =="
if lsof -nP -iTCP:${PORT} | rg -q 'LISTEN' && lsof -nP -iTCP:${PORT} | rg -q 'ESTABLISHED'; then
  echo "PASS: MCP bridge is listening and has an active connection."
  exit 0
fi

echo "WARN: MCP bridge is not fully connected (missing LISTEN or ESTABLISHED)."
echo "If this persists, restart Codex session and Godot editor, then run this script again."
exit 1
