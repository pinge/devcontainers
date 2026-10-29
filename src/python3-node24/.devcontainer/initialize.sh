#!/bin/bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  printf 'Usage: %s workspace-folder agents\n' "$0" >&2
  exit 2
fi
workspace_folder="$1"
agents="$2"

if [[ -n "$agents" ]]; then
  if [[ "$agents" == ,* || "$agents" == *, || "$agents" == *,,* ]]; then
    printf 'Invalid agents: %s\n' "$agents" >&2
    exit 2
  fi
  IFS=',' read -r -a selected_agents <<< "$agents"
  for agent in "${selected_agents[@]}"; do
    case "$agent" in
      claude) mkdir -p "${workspace_folder}/.devcontainer/.claude" ;;
      codex) mkdir -p "${workspace_folder}/.devcontainer/.codex" ;;
      muse) mkdir -p "${workspace_folder}/.devcontainer/.muse-data/sessions" ;;
      *) printf 'Invalid agent: %s\n' "$agent" >&2; exit 2 ;;
    esac
  done
fi

# reads the zone name from /etc/localtime on the host,
# with an unparseable time zone falling back to utc
container_env_file="${workspace_folder}/.devcontainer/.env"
host_tz=""
if link="$(readlink /etc/localtime 2>/dev/null)" && [[ "$link" == *zoneinfo/* ]]; then
  candidate="${link##*zoneinfo/}"
  if [[ "$candidate" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)+$ ]]; then
    host_tz="$candidate"
  fi
fi
printf 'TZ=%s\n' "${host_tz:-UTC}" > "$container_env_file"
