# 🚢 python3-node24

- 🐳 `mcr.microsoft.com/devcontainers/python:<version>-bookworm` (arm64)
- 🐍 Python 3.11, 3.12, 3.13, 3.14, or dev-3.15
- 📦 PDM 2.29.3
- ✳️ Node.js 24
- 🤖 Claude, Codex, and Muse
- 🔐 Credentials and sessions survive container rebuilds
- 🛡️ Seamless `.venv` isolation between host and container
- 🌍 Container inherits the host time zone
- ⚙️ Sane VS Code defaults

## Usage

```sh
npm install --global @devcontainers/cli

devcontainer templates apply \
  --template-id ghcr.io/pinge/devcontainers/python3-node24:latest \
  --template-args '{"python":"3.13"}' \
  --workspace-folder .
```

or

```sh
npx --yes --package @devcontainers/cli devcontainer templates apply \
  --template-id ghcr.io/pinge/devcontainers/python3-node24:latest \
  --template-args '{"python":"3.13"}' \
  --workspace-folder .
```

### Options

| Argument | Values                                                                | Default             |
| -------- | --------------------------------------------------------------------- | ------------------- |
| `python` | `3.11`, `3.12`, `3.13`, `3.14`, `dev-3.15`                            | `3.13`              |
| `agents` | Comma-delimited with `claude`, `codex`, `muse`                        | `claude,codex,muse` |

Set the `python` version and `agents` using template arguments:

```sh
devcontainer templates apply \
  --template-id ghcr.io/pinge/devcontainers/python3-node24:latest \
  --template-args '{"python":"dev-3.15","agents":"claude,codex"}' \
  --workspace-folder .
```

Skip installing agents

```sh
devcontainer templates apply \
  --template-id ghcr.io/pinge/devcontainers/python3-node24:latest \
  --template-args '{"agents":""}' \
  --workspace-folder .
```
