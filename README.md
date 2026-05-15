# cc-deck

**[🇰🇷 한국어](README.ko.md)**

> Claude Code session hub — find, track, and resume any session instantly

![demo](demo/demo_readme.gif)

Claude Code sessions pile up across projects. When you need to get back to something — whether it was yesterday's debugging session, a task Claude flagged for follow-up, or a session you bookmarked — finding it and resuming in the right context takes friction.

`cc-deck` removes that friction. It opens a fuzzy-searchable TUI over all your Claude Code sessions, with TODO items from Claude memory pinned at the top. Works on macOS (zsh), Linux (bash), and Windows (PowerShell).

---

## Features

- **Fuzzy search** — type anything to filter sessions by last input content
- **Auto-pinned TODOs** — Claude memory entries with `name: TODO...` appear at the top automatically
- **Manual PIN** — `Ctrl-K` to pin / unpin any session
- **Smart resume** — automatically `cd`s to the original directory before resuming
- **4 resume modes** — `claude`, `claude-api`, `--dangerously-skip-permissions`, and combinations
- **Mode persistence** — last selected mode remembered across runs
- **Fast** — mtime-based cache, ~0.04s on repeat runs

---

## Requirements

| | macOS | Windows | Linux |
|---|---|---|---|
| Shell | zsh | PowerShell 5.1+ | bash |
| Python | python3 | python (3.x) | python3 |
| fzf | `brew install fzf` | `winget install junegunn.fzf` | `apt/dnf install fzf` |

---

## Installation

**macOS (zsh)**

```zsh
git clone https://github.com/sysnet4admin/cc-deck.git ~/cc-deck
cd ~/cc-deck
./install.sh
source ~/.zshrc
```

**Linux (bash)**

```bash
git clone https://github.com/sysnet4admin/cc-deck.git ~/cc-deck
cd ~/cc-deck
./install.sh --bash
source ~/.bashrc
```

**Windows (PowerShell)**

```powershell
git clone https://github.com/sysnet4admin/cc-deck.git "$HOME\cc-deck"
. "$HOME\cc-deck\install.ps1"
```

Then add to your PowerShell profile (`$PROFILE`):

```powershell
. "$HOME\cc-deck\cc-deck.ps1"
```

---

## Usage

```
cc-deck
```

### Key bindings

| Key | Action |
|-----|--------|
| `Enter` | Resume with last saved mode |
| `Ctrl-K` | Pin / unpin current session |
| `Ctrl-R` | Mark TODO as done / remove PIN |
| `Ctrl-O` | Resume with `claude` |
| `Ctrl-A` | Resume with `claude-api` |
| `Ctrl-S` | Resume with `claude --dangerously-skip-permissions` |
| `Ctrl-X` | Resume with `claude-api --dangerously-skip-permissions` |
| `ESC` | Quit |

### Session list

```
[TODO] /tmp/projects/infra/k8s: Watch for OOMKill recurrence over the next 2 weeks
[PIN]  /tmp/projects/api-server: memory usage keeps climbing after the last deploy
────────────────────────────────────────────────────────────────────────
* 2026-05-08 09:14  /tmp/projects/api-server:    memory usage keeps climbing...
  2026-05-08 08:59  /tmp/projects/infra/k8s:    pod keeps OOMKilling after scaling up
  2026-05-08 08:38  /tmp/projects/frontend:     login form validation breaks on Safari
  2026-05-08 08:17  /tmp/projects/auth-service: refactor session tokens to JWT
  2026-05-08 07:59  /tmp/projects/monitoring:   set up Grafana SLO alerts
```

- `*` marks the current directory
- `[TODO]` — auto-detected from Claude memory (`type: project`, `name` contains `TODO`)
- `[PIN]` — manually pinned with `Ctrl-K`

### Default command override

**macOS / Linux:**
```bash
export CLAUDE_DECK_CMD="claude-api"
```

**Windows:**
```powershell
$env:CLAUDE_DECK_CMD = "claude-api"
```

---

## Tutorial

### 1. Finding a session with fuzzy search

```
cc-deck
```

Type `OOM` in the prompt — the list filters in real time to sessions where you were investigating OOM issues. Select one and `cc-deck` resumes it in the right directory.

```
cc-deck> OOM
  2/100
  2026-05-08 08:59  /tmp/projects/infra/k8s: pod keeps OOMKilling after scaling up
```

### 2. Tracking ongoing work with TODO

When you ask Claude to track something for later:

```
"add this to memory as a TODO"
"check back on this next week"
```

Claude writes a memory entry like:

```yaml
name: TODO - Monitor EKS cluster after 3Gi memory limit applied
type: project
originSessionId: a40fabf4-...
```

Next time you open `cc-deck`, this appears pinned at the top — linked back to the originating session.

### 3. Bookmarking a session with PIN

In the TUI, navigate to any session and press `Ctrl-K`. It pins the session with its last-input as the label. Press `Ctrl-K` again to unpin.

```
[PIN]  /tmp/projects/api-server: memory usage keeps climbing after the last deploy
```

### 4. Marking a TODO as done

When a TODO is resolved, press `Ctrl-R` on it. cc-deck removes `TODO` from the memory entry name and appends `(completed)` — the memory file itself is preserved so Claude still has the context.

```
# Before
name: TODO - Monitor EKS cluster after 3Gi applied

# After Ctrl-R
name: Monitor EKS cluster after 3Gi applied (completed)
```

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
