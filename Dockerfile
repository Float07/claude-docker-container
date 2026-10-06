# Ubuntu dev container for Claude Code projects
FROM ubuntu:24.04

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG NVM_VERSION=v0.40.8
ARG NODE_VERSION=lts/*

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=America/Sao_Paulo

# Base tools + Python
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget git openssh-client gnupg sudo \
        build-essential pkg-config unzip zip less nano vim \
        jq ripgrep fd-find tree htop procps locales tzdata bash-completion \
        python3 python3-pip python3-venv python3-dev python-is-python3 \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# uv (fast Python package/venv manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh

# Non-root user matching your host UID/GID (so files in your project keep your ownership).
# Ubuntu 24.04 ships a default "ubuntu" user at UID 1000 — remove it first.
RUN (userdel -r ubuntu 2>/dev/null || true) \
    && (getent group ${USER_GID} || groupadd --gid ${USER_GID} ${USERNAME}) \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# nvm lives outside $HOME so it isn't affected by volumes, but is owned by the user
ENV NVM_DIR=/usr/local/nvm
RUN mkdir -p ${NVM_DIR} /workspace /home/${USERNAME}/.claude /commandhistory \
    && chown -R ${USER_UID}:${USER_GID} ${NVM_DIR} /workspace /home/${USERNAME}/.claude /commandhistory

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# nvm + Node LTS + Claude Code
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | PROFILE=/dev/null bash \
    && . ${NVM_DIR}/nvm.sh \
    && nvm install "${NODE_VERSION}" \
    && nvm alias default "${NODE_VERSION}" \
    && npm install -g @anthropic-ai/claude-code \
    && nvm cache clear \
    && ln -s ${NVM_DIR}/versions/node/$(nvm version default) ${NVM_DIR}/current

# Make node/npm/claude available in every shell (including non-interactive `docker exec`)
ENV PATH=${NVM_DIR}/current/bin:/home/${USERNAME}/.local/bin:${PATH} \
    CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude \
    SHELL=/bin/bash

RUN { \
      echo ''; \
      echo '# nvm'; \
      echo 'export NVM_DIR=/usr/local/nvm'; \
      echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'; \
      echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'; \
      echo ''; \
      echo '# persistent history'; \
      echo 'export HISTFILE=/commandhistory/.bash_history'; \
      echo 'export PROMPT_COMMAND="history -a; ${PROMPT_COMMAND}"'; \
      echo ''; \
      echo 'PS1="\[\e[35m\](claude-box)\[\e[0m\] \[\e[36m\]\w\[\e[0m\] \$ "'; \
    } >> ~/.bashrc

WORKDIR /workspace
CMD ["bash"]
