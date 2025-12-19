#!/usr/bin/env bash
set -euo pipefail

# Write MCP config to mcp.json at repo root.
cat > mcp.json <<'EOF'
{
  "servers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp", "--api-key", "ctx7sk-09a4f9c8-bf34-4be0-bccb-2b231ebd2809"]
    }
  }
}
EOF

# Update VS Code workspace settings to register the MCP server.
mkdir -p .vscode
python3 - <<'PY'
import json, os

settings_path = os.path.join(".vscode", "settings.json")
try:
    with open(settings_path, "r", encoding="utf-8") as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}

servers = settings.get("mcp.servers", {})
servers["context7"] = {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp", "--api-key", "ctx7sk-09a4f9c8-bf34-4be0-bccb-2b231ebd2809"]
}

settings["mcp.servers"] = servers

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY

echo "mcp.json created and VS Code settings updated with context7 server."
