# 🚢 python3-node24

- 🐳 `mcr.microsoft.com/devcontainers/python:<version>-bookworm` (arm64)
- 🐍 Python 3.11, 3.12, 3.13, 3.14, or dev-3.15
- 📦 PDM 2.29.3
- ✳️ Node.js 24
- 🤖 Claude, Codex, and Muse
- 🔐 Credentials and sessions survive container rebuilds
- 🌍 Container inherits the host time zone
- ⚙️ Sane VS Code defaults

## Usage

```sh
npm install --global @devcontainers/cli

devcontainer templates apply \
  --template-id ghcr.io/pinge/devcontainers/python3-node24:latest \
  --template-args '{"python":"3.11"}' \
  --workspace-folder .
```

or

```sh
npx --yes --package @devcontainers/cli devcontainer templates apply \
  --template-id ghcr.io/pinge/devcontainers/python3-node24:latest \
  --template-args '{"python":"3.11"}' \
  --workspace-folder .
```
