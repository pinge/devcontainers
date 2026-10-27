# 🚢 python315-node24

- 🐳 `mcr.microsoft.com/devcontainers/python:dev-3.15-bookworm` (arm64)
- 🐍 Python 3.15
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
  --template-id ghcr.io/pinge/devcontainers/python315-node24:latest \
  --workspace-folder .
```

or

```sh
npx --yes --package @devcontainers/cli devcontainer templates apply \
  --template-id ghcr.io/pinge/devcontainers/python315-node24:latest \
  --workspace-folder .
```
