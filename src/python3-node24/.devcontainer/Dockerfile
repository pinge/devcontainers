FROM mcr.microsoft.com/devcontainers/python:${templateOption:python}-bookworm

ENV PATH="/home/vscode/.local/bin:${PATH}"

USER vscode
# use pdm's python installer to avoid the standalone binary's glibc requirement
# https://pdm-project.org/latest/#install-via-python-script
RUN /bin/bash -o pipefail -c 'curl -fsSL https://pdm-project.org/install-pdm.py | python - -v 2.29.3 >/dev/null'
