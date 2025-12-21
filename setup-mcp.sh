#!/usr/bin/env bash
# Regenerate mcp.json and update VS Code MCP settings.
set -euo pipefail

root_dir="$(pwd)"

mkdir -p "${root_dir}/.vscode"

cat > "${root_dir}/.vscode/mcp.json" <<'EOF'
{
  "servers": {
    "shadcn": {
      "command": "npx",
      "args": ["shadcn@latest", "mcp"]
    },
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp", "--api-key", "ctx7sk-09a4f9c8-bf34-4be0-bccb-2b231ebd2809"]
    }
  }
}
EOF

python3 - <<'PY'
import json, pathlib

root = pathlib.Path(".").resolve()
vscode_dir = root / ".vscode"
mcp_path = vscode_dir / "mcp.json"
settings_path = vscode_dir / "settings.json"

try:
    with settings_path.open("r", encoding="utf-8") as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}

with mcp_path.open("r", encoding="utf-8") as f:
    desired = json.load(f).get("servers", {})

servers = settings.get("mcp.servers", {})
servers.update(desired)
settings["mcp.servers"] = servers

settings_path.parent.mkdir(parents=True, exist_ok=True)
with settings_path.open("w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY

echo ".vscode/mcp.json regenerated"
echo ".vscode/settings.json updated with shadcn and context7 servers"
