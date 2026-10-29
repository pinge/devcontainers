#!/bin/bash
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$CONFIG_DIR/.." && pwd)"
sudo mkdir -p "$WORKSPACE_DIR/.venv"
sudo chown vscode:vscode "$WORKSPACE_DIR/.venv"

python --version
printf 'NodeJS %s\n' "$(node --version)"

pdm --version

printf 'NPM %s\n' "$(npm --version)"

if [[ ",${INSTALL_AGENTS}," == *,claude,* ]]; then
  npm_config_update_notifier=false npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code >/dev/null
  claude --version
fi

if [[ ",${INSTALL_AGENTS}," == *,codex,* ]]; then
  npm_config_update_notifier=false npm install -g @openai/codex >/dev/null
  codex --version
fi

if [[ ",${INSTALL_AGENTS}," == *,muse,* ]]; then
  MUSE_INSTALLER="$(mktemp)"
  curl -fsSL https://dev.meta.ai/install.sh -o "$MUSE_INSTALLER"
  MUSE_NO_MODIFY_PATH=1 bash "$MUSE_INSTALLER"
  rm -f "$MUSE_INSTALLER"
  hash -r
  muse --version
fi

if [[ ",${INSTALL_AGENTS}," == *,muse,* ]]; then
  MUSE_ALIAS="alias muse='muse --disable-sandbox'"
  if ! grep -qF "$MUSE_ALIAS" /home/vscode/.bashrc 2>/dev/null; then
    printf '\n%s\n' "$MUSE_ALIAS" >> /home/vscode/.bashrc
  fi
fi

echo ".devcontainer time zone: $TZ"

if [[ ",${INSTALL_AGENTS}," == *,claude,* ]]; then
  if [ ! -f "$CONFIG_DIR/.claude/keybindings.json" ]; then
    cp "$CONFIG_DIR/claude/keybindings.json" "$CONFIG_DIR/.claude/keybindings.json"
  fi
  if [ ! -f "$CONFIG_DIR/.claude/settings.json" ]; then
    cp "$CONFIG_DIR/claude/settings.json" "$CONFIG_DIR/.claude/settings.json"
  fi
fi
if [[ ",${INSTALL_AGENTS}," == *,codex,* ]]; then
  if [ ! -f "$CONFIG_DIR/.codex/config.toml" ]; then
    sed "s|__WORKSPACE_ROOT__|$(cd "$CONFIG_DIR/.." && pwd)|g" "$CONFIG_DIR/codex/config.toml" > "$CONFIG_DIR/.codex/config.toml"
  fi
  if [ ! -f "$CONFIG_DIR/.codex/rules/confirm-rm.rules" ]; then
    mkdir -p "$CONFIG_DIR/.codex/rules"
    cp "$CONFIG_DIR/codex/rules/confirm-rm.rules" "$CONFIG_DIR/.codex/rules/confirm-rm.rules"
  fi
fi
if [[ ",${INSTALL_AGENTS}," == *,muse,* ]]; then
  mkdir -p /home/vscode/.config/muse
  if [ ! -f /home/vscode/.config/muse/settings.json ]; then
    cp "$CONFIG_DIR/muse/settings.json" /home/vscode/.config/muse/settings.json
  fi
  MUSE_SETTINGS=/home/vscode/.config/muse/settings.json
  # muse settings may lack the permissions schema version and the cli can error with:
  # Named permission profiles are unavailable: missing field `schema_version` at line 3 column 3.
  if jq -e 'if (.permissions | type) == "object" then (.permissions | has("schema_version") | not) else false end' "$MUSE_SETTINGS" >/dev/null; then
    MUSE_SETTINGS_JSON="$(jq '.permissions.schema_version = 1' "$MUSE_SETTINGS")"
    printf '%s\n' "$MUSE_SETTINGS_JSON" > "$MUSE_SETTINGS"
  fi
fi

bash "$CONFIG_DIR/restore_links.sh"
