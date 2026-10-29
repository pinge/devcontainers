#!/bin/bash
set -euo pipefail

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../src/python3-node24" && pwd)"
TEMP_DIR="${TMPDIR:-/tmp}"
PYTHON_IMAGE_VERSION="${1:-3.13}"
case "$PYTHON_IMAGE_VERSION" in
  3.11|3.12|3.13|3.14|dev-3.15) ;;
  *) printf 'Unsupported Python version: %s\n' "$PYTHON_IMAGE_VERSION" >&2; exit 2 ;;
esac
EXPECTED_PYTHON="${PYTHON_IMAGE_VERSION#dev-}"
if [[ "$#" -gt 2 ]]; then
  printf 'Usage: %s [python-version [agent-list]]\n' "$0" >&2
  exit 2
fi
AGENTS="${2:-}"
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_MUSE=false
if [[ -n "$AGENTS" ]]; then
  if [[ "$AGENTS" == ,* || "$AGENTS" == *, || "$AGENTS" == *,,* ]]; then
    printf 'Invalid agents: %s\n' "$AGENTS" >&2
    exit 2
  fi
  IFS=',' read -r -a SELECTED_AGENTS <<< "$AGENTS"
  for selected_agent in "${SELECTED_AGENTS[@]}"; do
    case "$selected_agent" in
      claude) INSTALL_CLAUDE=true ;;
      codex) INSTALL_CODEX=true ;;
      muse) INSTALL_MUSE=true ;;
      *) printf 'Unknown agent: %s\n' "$selected_agent" >&2; exit 2 ;;
    esac
  done
fi
TEST_DIR="$(mktemp -d "${TEMP_DIR%/}/test-vsc-devcontainer-python3-node24-XXXXXX")"
TEST_NAME="$(basename "$TEST_DIR" | tr '[:upper:]' '[:lower:]')"

is_test_image_repository() {
  local repository="$1"
  local image_hash

  [[ "$repository" == "vsc-${TEST_NAME}-"* ]] || return 1
  image_hash="${repository#vsc-${TEST_NAME}-}"
  case "$image_hash" in
    *-features-uid) image_hash="${image_hash%-features-uid}" ;;
    *-features) image_hash="${image_hash%-features}" ;;
    *-uid) image_hash="${image_hash%-uid}" ;;
  esac
  [[ "$image_hash" =~ ^[[:xdigit:]]{64}$ ]]
}

get_venv_volume() {
  local container_id="$1"
  local mounts
  local mount_type
  local mount_name
  local mount_target
  local volume=""

  mounts="$(docker inspect --format '{{range .Mounts}}{{.Type}}|{{.Name}}|{{.Destination}}{{println}}{{end}}' "$container_id")" || return 1
  while IFS='|' read -r mount_type mount_name mount_target; do
    if [[ "$mount_type" == volume && "$mount_target" == */.venv ]]; then
      [[ -z "$volume" && "$mount_name" =~ ^[[:alnum:]]+-venv$ ]] || return 1
      volume="$mount_name"
    fi
  done <<< "$mounts"
  [[ -n "$volume" ]] || return 1
  printf '%s\n' "$volume"
}

cleanup() {
  local status=$?
  local container_id
  local container_info
  local container_name
  local container_image
  local container_repository
  local container_workspace
  local container_running
  local container_venv_volume
  local volume_containers
  local volume_name
  local image_ref
  local image_repository
  local image_info
  local image_id
  local image_tags
  local image_containers

  trap - EXIT
  while IFS= read -r container_id; do
    [ -n "$container_id" ] || continue
    if ! container_info="$(docker inspect --format '{{.Name}}|{{.Config.Image}}|{{index .Config.Labels "devcontainer.local_folder"}}' "$container_id" 2>/dev/null)"; then
      status=1
      continue
    fi
    IFS='|' read -r container_name container_image container_workspace <<< "$container_info"
    container_name="${container_name#/}"
    if [[ "$container_workspace" != "$TEST_DIR" || ! "$container_name" =~ ^[[:alnum:]][[:alnum:]_.-]*$ ]]; then
      status=1
      continue
    fi
    container_repository="${container_image%:*}"
    if is_test_image_repository "$container_repository"; then
      if ! container_venv_volume="$(get_venv_volume "$container_id" 2>/dev/null)"; then
        status=1
        continue
      fi
      if ! container_running="$(docker inspect --format '{{.State.Running}}' "$container_id" 2>/dev/null)"; then
        status=1
        continue
      fi
      if [[ "$container_running" == true ]] && ! docker stop "$container_id" >/dev/null; then
        status=1
        continue
      fi
      if ! container_running="$(docker inspect --format '{{.State.Running}}' "$container_id" 2>/dev/null)" || [[ "$container_running" != false ]]; then
        status=1
        continue
      fi
      if ! docker rm "$container_id" >/dev/null || docker container inspect "$container_id" >/dev/null 2>&1; then
        status=1
        continue
      fi
      if ! volume_containers="$(docker ps -aq --filter "volume=$container_venv_volume" 2>/dev/null)" || [[ -n "$volume_containers" ]]; then
        status=1
        continue
      fi
      if ! volume_name="$(docker volume inspect --format '{{.Name}}' "$container_venv_volume" 2>/dev/null)" || [[ "$volume_name" != "$container_venv_volume" ]]; then
        status=1
        continue
      fi
      if ! docker volume rm "$container_venv_volume" >/dev/null || docker volume inspect "$container_venv_volume" >/dev/null 2>&1; then
        status=1
      fi
    else
      status=1
    fi
  done < <(docker ps -aq --filter "label=devcontainer.local_folder=$TEST_DIR" 2>/dev/null || true)

  while IFS= read -r image_ref; do
    [ -n "$image_ref" ] || continue
    if ! image_info="$(docker image inspect --format '{{.Id}}|{{range .RepoTags}}{{.}} {{end}}' "$image_ref" 2>/dev/null)"; then
      status=1
      continue
    fi
    image_id="${image_info%%|*}"
    image_tags="${image_info#*|}"
    if [[ ! "$image_id" =~ ^sha256:[[:xdigit:]]{64}$ || " $image_tags " != *" $image_ref "* ]]; then
      status=1
      continue
    fi
    if ! image_containers="$(docker ps -aq --filter "ancestor=$image_id" 2>/dev/null)" || [[ -n "$image_containers" ]]; then
      status=1
      continue
    fi
    docker image rm "$image_ref" >/dev/null || status=$?
  done < <(
    docker image ls --format '{{.Repository}}:{{.Tag}}' 2>/dev/null |
      while IFS= read -r image_ref; do
        image_repository="${image_ref%:*}"
        if is_test_image_repository "$image_repository"; then
          printf '%s\n' "$image_ref"
        fi
      done
  )

  rm -rf "$TEST_DIR" || status=$?
  exit "$status"
}
trap cleanup EXIT

# test template configuration, image build, and container launch
cp -R "$TEMPLATE_DIR/." "$TEST_DIR/"
DOCKERFILE="$TEST_DIR/.devcontainer/Dockerfile"
DOCKERFILE_CONTENT="$(<"$DOCKERFILE")"
DOCKERFILE_CONTENT="${DOCKERFILE_CONTENT//\$\{templateOption:python\}/$PYTHON_IMAGE_VERSION}"
printf '%s\n' "$DOCKERFILE_CONTENT" > "$DOCKERFILE"
DEVCONTAINER_JSON="$TEST_DIR/.devcontainer/devcontainer.json"
DEVCONTAINER_CONTENT="$(<"$DEVCONTAINER_JSON")"
DEVCONTAINER_CONTENT="${DEVCONTAINER_CONTENT//\$\{templateOption:agents\}/$AGENTS}"
printf '%s\n' "$DEVCONTAINER_CONTENT" > "$DEVCONTAINER_JSON"
# test dependency installation and host virtualenv isolation
mkdir -p "$TEST_DIR/.venv"
printf 'host venv\n' > "$TEST_DIR/.venv/host-marker"
cat > "$TEST_DIR/pyproject.toml" <<'TOML'
[project]
name = "venv-isolation-test"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = ["idna==3.10"]
TOML
if [[ "$INSTALL_CLAUDE" == true ]]; then
  mkdir -p "$TEST_DIR/.devcontainer/.claude"
  printf '{}\n' > "$TEST_DIR/.devcontainer/.claude/.claude.json"
fi
devcontainer read-configuration --workspace-folder "$TEST_DIR" >/dev/null
devcontainer build --workspace-folder "$TEST_DIR"
devcontainer up --workspace-folder "$TEST_DIR"
CONTAINER_ID="$(docker ps -q --filter "label=devcontainer.local_folder=$TEST_DIR")"
test -n "$CONTAINER_ID"
test "$(printf '%s\n' "$CONTAINER_ID" | wc -l)" -eq 1
docker rename "$CONTAINER_ID" "$TEST_NAME"

# assert time zone
EXPECTED_TZ="$(sed -n 's/^TZ=//p' "$TEST_DIR/.devcontainer/.env")"

test -n "$EXPECTED_TZ"
# assert runtime versions, virtualenv, configuration files, and symlinks
assert_runtime() {
  devcontainer exec --workspace-folder "$TEST_DIR" env \
    "EXPECTED_TZ=$EXPECTED_TZ" \
    "EXPECTED_PYTHON=$EXPECTED_PYTHON" \
    "EXPECTED_INSTALL_CLAUDE=$INSTALL_CLAUDE" \
    "EXPECTED_INSTALL_CODEX=$INSTALL_CODEX" \
    "EXPECTED_INSTALL_MUSE=$INSTALL_MUSE" \
    bash -c '
set -euo pipefail

test "$(id -un)" = vscode
test -w .venv
test ! -e .venv/host-marker
python -c "import os, sys; assert \".\".join(map(str, sys.version_info[:2])) == os.environ[\"EXPECTED_PYTHON\"]"
node -e "if (Number(process.versions.node.split(\".\")[0]) !== 24) process.exit(1)"
[[ "$(pdm --version)" == *2.29.3* ]]
pdm run python -c "import idna, sys; assert idna.__version__ == \"3.10\"; assert sys.prefix.endswith(\"/.venv\")"
[[ "$TZ" == "$EXPECTED_TZ" ]]

workspace_root="$(pwd -P)"
if [[ "$EXPECTED_INSTALL_CLAUDE" == true ]]; then
  command -v claude >/dev/null
  claude --version
  test -L /home/vscode/.claude.json
  [[ "$(readlink -f /home/vscode/.claude.json)" == "$workspace_root/.devcontainer/.claude/.claude.json" ]]
  cmp -s "$workspace_root/.devcontainer/claude/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
else
  ! command -v claude >/dev/null 2>&1
  [[ ! -e "$CLAUDE_CONFIG_DIR" && ! -L "$CLAUDE_CONFIG_DIR" ]]
  [[ ! -L /home/vscode/.claude.json ]]
fi

if [[ "$EXPECTED_INSTALL_CODEX" == true ]]; then
  command -v codex >/dev/null
  codex --version
  sed "s|__WORKSPACE_ROOT__|$workspace_root|g" "$workspace_root/.devcontainer/codex/config.toml" | cmp -s - "$CODEX_HOME/config.toml"
  cmp -s "$workspace_root/.devcontainer/codex/rules/confirm-rm.rules" "$CODEX_HOME/rules/confirm-rm.rules"
else
  ! command -v codex >/dev/null 2>&1
  [[ ! -e "$CODEX_HOME" && ! -L "$CODEX_HOME" ]]
fi

if [[ "$EXPECTED_INSTALL_MUSE" == true ]]; then
  command -v muse >/dev/null
  muse --version
  test -L /home/vscode/.local/share/muse/sessions
  [[ "$(readlink -f /home/vscode/.local/share/muse/sessions)" == "$workspace_root/.devcontainer/.muse-data/sessions" ]]
  cmp -s "$workspace_root/.devcontainer/muse/settings.json" /home/vscode/.config/muse/settings.json
else
  ! command -v muse >/dev/null 2>&1
  [[ ! -e "$workspace_root/.devcontainer/.muse-data" && ! -L "$workspace_root/.devcontainer/.muse-data" ]]
  [[ ! -L /home/vscode/.local/share/muse/sessions ]]
  [[ ! -e /home/vscode/.config/muse/settings.json ]]
fi
'
}

devcontainer exec --workspace-folder "$TEST_DIR" pdm install --no-self
assert_runtime
test -f "$TEST_DIR/.venv/host-marker"
test ! -e "$TEST_DIR/.venv/pyvenv.cfg"

# assert container name, workspace label, and image name
CONTAINER_ID="$(docker ps -q --filter "label=devcontainer.local_folder=$TEST_DIR")"
test -n "$CONTAINER_ID"
test "$(printf '%s\n' "$CONTAINER_ID" | wc -l)" -eq 1
CONTAINER_INFO="$(docker inspect --format '{{.Name}}|{{.Config.Image}}|{{index .Config.Labels "devcontainer.local_folder"}}' "$CONTAINER_ID")"
IFS='|' read -r CONTAINER_NAME CONTAINER_IMAGE CONTAINER_WORKSPACE <<< "$CONTAINER_INFO"
CONTAINER_NAME="${CONTAINER_NAME#/}"
CONTAINER_REPOSITORY="${CONTAINER_IMAGE%:*}"
[[ "$CONTAINER_WORKSPACE" == "$TEST_DIR" ]]
[[ "$CONTAINER_NAME" == "$TEST_NAME" ]]
is_test_image_repository "$CONTAINER_REPOSITORY"
docker stop "$CONTAINER_ID" >/dev/null

# assert setup and runtime state after restart
devcontainer up --workspace-folder "$TEST_DIR"
devcontainer run-user-commands --workspace-folder "$TEST_DIR"
assert_runtime


