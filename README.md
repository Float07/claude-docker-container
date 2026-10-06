# claude-box

An Ubuntu 24.04 container for running Claude Code on your projects, kept separate from your machine. Only the project folder you're in gets mounted.

**Included:** Claude Code, nvm + Node LTS + npm, Python 3 + pip + venv + uv, git, gh, build-essential, ripgrep, fd, jq, and passwordless `sudo` inside the container.

## Install

```bash
# put the folder somewhere permanent, e.g. ~/tools/claude-box
chmod +x ~/tools/claude-box/claude-box
ln -s ~/tools/claude-box/claude-box ~/.local/bin/claude-box   # anywhere on your PATH

claude-box build
```

The image is built with your host UID/GID, so files created in the container belong to you on the host.

## Use

```bash
cd ~/code/my-project
claude-box claude        # run Claude Code here
claude-box               # or open a shell, then run `claude`
```

The first time, log in with `/login`, or set an API key with `export ANTHROPIC_API_KEY=...`. The login is kept in a Docker volume that all projects share, so you only need to log in once.

| Command | What it does |
|---|---|
| `claude-box` | Opens a bash shell in this folder's container |
| `claude-box claude [args]` | Runs Claude Code, e.g. `claude-box claude --continue` |
| `claude-box <cmd>` | Runs any command, e.g. `claude-box npm test` |
| `claude-box stop` | Removes this folder's container. Your files and login are kept |
| `claude-box ls` / `prune` | Lists or removes all claude-box containers |
| `claude-box build` | Rebuilds the image, e.g. `claude-box build --no-cache` for a fresh Claude/Node |

Each project folder gets its own long-running container, mounted at `/workspace/<folder-name>`. If you run `claude-box` again in another terminal, it attaches to the same container. Anything you install with `apt`, `pip` or `nvm` stays until you run `claude-box stop`.

### Options

```bash
CLAUDE_BOX_PORTS="3000 8000" claude-box     # publish ports for dev servers (set when the container is created)
CLAUDE_BOX_GITCONFIG=1 claude-box           # mount ~/.gitconfig read-only for commit name/email
```

If you change these on a container that's already running, run `claude-box stop` first so they take effect.

Dev servers inside the container need to listen on `0.0.0.0` (not `localhost`) to be reachable from your browser.

## What's isolated

- **Mounted:** only the current project folder (read/write).
- **Not mounted:** your home directory, SSH keys, cloud credentials, and other projects.
- **Network:** full internet access, and Claude's permission prompts stay on.

To push to GitHub, run `gh auth login` inside the container. The token is stored in the container, not on your host.

## Customize

Edit the `Dockerfile`, then run `claude-box build` and `claude-box prune`. Some useful build args:

```bash
claude-box build --build-arg NODE_VERSION=22
```

To reset everything, including your login and history:

```bash
claude-box prune
docker volume rm claude-box-config claude-box-history
```
