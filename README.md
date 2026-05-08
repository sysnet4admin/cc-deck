# cc-deck

**[🇰🇷 한국어](README.ko.md)**

> Claude Code session browser and task manager

![demo](demo/demo.gif)

When you work across multiple projects with Claude Code, it gets hard to track where you left off. `claude --resume` shows a session list, but the summaries are compressed and you can't tell which session was which.

`cc-deck` opens an fzf TUI showing all your past sessions with the **last thing you typed** as a preview. TODOs from Claude memory are pinned at the top automatically. Select a session and it `cd`s to the right directory before resuming.

---

## Features

- **Session browser** — fzf TUI with last-input preview, sorted by recency
- **Auto-pinned TODOs** — Claude memory entries (`type: project`, `name: TODO...`) appear at the top automatically
- **Manual pin** — `Ctrl-K` to pin / unpin any session
- **Smart resume** — automatically `cd`s to the original directory before resuming
- **4 resume modes** — switch between `claude`, `claude-api`, `--dangerously-skip-permissions`, and combinations
- **Mode persistence** — last selected mode is remembered across runs
- **Fast** — mtime-based cache keeps repeat runs at ~0.04s

---

## Requirements

- macOS (Linux support planned)
- zsh
- python3
- [fzf](https://github.com/junegunn/fzf) — `brew install fzf`

---

## Installation

```zsh
git clone https://github.com/sysnet4admin/cc-deck.git ~/cc-deck
cd ~/cc-deck
./install.sh
source ~/.zshrc
```

`install.sh` adds a `source` line to `~/.zshrc` automatically.

---

## Usage

```
cc-deck
```

### Key bindings

| Key | Action |
|-----|--------|
| `Enter` | Resume with last saved mode |
| `Ctrl-K` | Pin / unpin current session (toggle) |
| `Ctrl-O` | Resume with `claude` |
| `Ctrl-A` | Resume with `claude-api` |
| `Ctrl-D` | Resume with `claude --dangerously-skip-permissions` |
| `Ctrl-X` | Resume with `claude-api --dangerously-skip-permissions` |
| `ESC` | Quit |

### Session list

```
[TODO] /tmp/projects/infra/k8s: Watch for OOMKill recurrence over the next 2 weeks
[PIN]  /tmp/projects/api-server: how do we fix it without rolling back?
────────────────────────────────────────────────────────────────────────
* 2026-05-08 09:14  /tmp/projects/api-server:    how do we fix it without rolling back?
  2026-05-08 08:59  /tmp/projects/infra/k8s:    applied — monitor it and let me know if OOMKills again
  2026-05-08 08:38  /tmp/projects/frontend:     what's the fix?
  2026-05-08 08:17  /tmp/projects/auth-service: what about token revocation?
  2026-05-08 07:59  /tmp/projects/monitoring:   also add an error rate alert
```

- `*` marks the current directory
- `[TODO]` entries are detected automatically from Claude memory (`type: project`, name starts with `TODO`)
- `[PIN]` entries are manually pinned with `Ctrl-K`

### Default command override

```zsh
export CLAUDE_DECK_CMD="claude-api"
# or
export CLAUDE_DECK_CMD="claude --dangerously-skip-permissions"
```

---

## How TODOs work

When you tell Claude to remember something for later:

```
add this to memory as a TODO
check back on this next week
keep an eye on this for a few days
```

Claude writes a memory file with `type: project` and `name: TODO - ...`. cc-deck detects these automatically and pins them at the top of the session list, linking back to the originating session via `originSessionId`.

---

## Files

| Path | Purpose |
|------|---------|
| `~/.claude/.cc-deck-cache.json` | mtime-based session cache |
| `~/.claude/.cc-deck-pins.json` | manually pinned sessions |
| `~/.claude/.cc-deck-mode` | last selected resume mode |

---

## Made with Claude Code

[![Claude](https://img.shields.io/badge/Made%20with-Claude%20Code-orange)](https://claude.ai/code)
