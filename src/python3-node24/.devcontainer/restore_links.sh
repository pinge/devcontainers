#!/bin/bash
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$CONFIG_DIR/.." && pwd)"

if [[ ",${INSTALL_AGENTS}," == *,claude,* ]]; then
  mkdir -p "$CONFIG_DIR/.claude"
  if [ ! -e /home/vscode/.claude.json ] && [ -f "$CONFIG_DIR/.claude/.claude.json" ]; then
    ln -sfn "$CONFIG_DIR/.claude/.claude.json" /home/vscode/.claude.json
  fi
  if [ -f /home/vscode/.claude.json ] && [ ! -L /home/vscode/.claude.json ] && [ ! -f "$CONFIG_DIR/.claude/.claude.json" ]; then
    cp /home/vscode/.claude.json "$CONFIG_DIR/.claude/.claude.json"
    ln -sf "$CONFIG_DIR/.claude/.claude.json" /home/vscode/.claude.json
  fi
fi

if [[ ",${INSTALL_AGENTS}," == *,codex,* ]]; then
  mkdir -p "$CONFIG_DIR/.codex"
fi

if [[ ",${INSTALL_AGENTS}," == *,muse,* ]]; then
  mkdir -p "$CONFIG_DIR/.muse-data/sessions" /home/vscode/.local/share/muse
  MUSE_LINK="/home/vscode/.local/share/muse/sessions"
  if [ ! -e "$MUSE_LINK" ]; then
    ln -sfn "$CONFIG_DIR/.muse-data/sessions" "$MUSE_LINK"
  fi
fi
