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
- **Tab mode cycle** — press Tab to rotate through resume modes; current mode shown in header
- **Mode persistence** — last selected mode remembered across runs
- **Quick query** — `cc-deck -q` for instant one-shot queries or ephemeral sessions (no history saved)
- **[Quick] sessions** — preserved quick sessions appear in the TUI; enter to browse and resume
- **Session size management** — oversized sessions (which slow down `claude --resume`) are surfaced in a "sessions to manage" group. Old rewind snapshots are auto-pruned (lossless); `Ctrl-E` trims conversation-heavy sessions while keeping recent turns (full session archived first)
- **Auto-update** — daily background update check; `cc-deck update` to update manually
- **Fast** — mtime-based cache, ~0.04s on repeat runs

---

## Requirements

| | macOS | Windows | Linux |
|---|---|---|---|
| Shell | zsh | PowerShell 5.1+ | bash |
| Git | pre-installed | `winget install Git.Git` | pre-installed |
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

To manually trigger an update:

```
cc-deck update
```

### Quick query

Ask a one-shot question without saving any session history:

```zsh
cc-deck -q "what is the difference between kubectl apply and replace?"
```

Or open an interactive ephemeral session (conversation is preserved for 7 days, then auto-deleted):

```zsh
cc-deck -q
```

Press `Ctrl-Q` inside the TUI for a quick query without leaving the session browser.

### Key bindings

| Key | Action |
|-----|--------|
| `Enter` | Resume with last saved mode |
| `Tab` | Cycle resume mode (default → api → skip → api+skip) |
| `Ctrl-K` | Pin / unpin current session |
| `Ctrl-R` | Mark TODO as done / remove PIN or Quick session |
| `Ctrl-Q` | Quick query (no session saved) |
| `Ctrl-G` | Prune old snapshots — lossless, shrinks file size |
| `Ctrl-E` | Trim to recent turns — lossy, archives full session first |
| `Ctrl-O` | Resume with `claude` |
| `Ctrl-A` | Resume with `claude-api` |
| `Ctrl-S` | Resume with `claude --dangerously-skip-permissions` |
| `Ctrl-X` | Resume with `claude-api --dangerously-skip-permissions` |
| `F1` | Show help |
| `ESC` | Quit |

### Session list

```
[TODO]  /tmp/projects/infra/k8s: Watch for OOMKill recurrence over the next 2 weeks
[PIN]   /tmp/projects/api-server: memory usage keeps climbing after the last deploy
[Quick] ▶ 2 sessions
──────────────── sessions to manage (large) ────────────────
[122M] /tmp/projects/books: chapter draft review and rewrite
 [77M] /tmp/projects/research: keep-alive tuning results
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
- `[Quick]` — preserved quick sessions (press Enter to browse)
- `[NNM]` (orange ≥50MB / red ≥100MB) — oversized sessions, surfaced for cleanup regardless of recency (`Ctrl-G` / `Ctrl-E`)

### Default command override

**macOS / Linux:**
```bash
export CLAUDE_DECK_CMD="claude-api"
```

**Windows:**
```powershell
$env:CLAUDE_DECK_CMD = "claude-api"
```

### Available modes

cc-deck automatically detects which resume modes to show:

| Condition | Modes shown |
|---|---|
| `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN` is set | all 4 modes |
| API-related vars found in `~/.zshrc` / `~/.bashrc` | all 4 modes |
| Neither detected | `default`, `dangerous` only |

For non-standard setups (LiteLLM, custom proxies, etc.), override explicitly:

**macOS / Linux:**
```bash
export CC_DECK_MODES="default,api,dangerous,api-dangerous"
```

**Windows:**
```powershell
$env:CC_DECK_MODES = "default,api,dangerous,api-dangerous"
```

Valid mode names: `default`, `api`, `dangerous`, `api-dangerous`

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

### 5. Quick queries

For quick questions that don't need a permanent session:

```zsh
# One-shot: answer printed, no session saved
cc-deck -q "explain the difference between RollingUpdate and Recreate"

# Interactive: full conversation, session auto-deleted after 7 days
cc-deck -q
```

Important sessions from `cc-deck -q` (2+ exchanges) are preserved and appear as `[Quick] ▶ N sessions` in the TUI. Press Enter on `[Quick]` to browse and resume them.

### 6. Managing oversized sessions

A long-running session's `.jsonl` can grow to hundreds of MB, which makes `claude --resume` slow (the whole file is loaded into memory). cc-deck surfaces these below `[Quick]` in a **"sessions to manage"** group, regardless of how recently they were used:

```
──────────────── sessions to manage (large) ────────────────
[122M] /tmp/projects/books: chapter draft review and rewrite
 [77M] /tmp/projects/research: keep-alive tuning results
```

Two cleanup levers, both keep the same session id so resume keeps working:

- **`Ctrl-G` — prune snapshots (lossless).** Most bloat is usually old `file-history-snapshot` entries (rewind checkpoints), which are cumulative and contribute nothing to the conversation. Pruning keeps the last few and drops the rest. Conversation is untouched. Sessions ≥100MB are also pruned automatically on launch.
- **`Ctrl-E` — trim to recent turns (lossy).** When a session is large because of conversation itself, this keeps only the last ~10 turns and **gzip-archives the full session to `~/.claude/_archive/` first**. You keep recent context; the complete history is safely stored.

Snapshot pruning preserves the original modification time, so cleaned-up old sessions don't jump to the top of the list.

### Size management settings

| Variable | Default | Meaning |
|---|---|---|
| `CC_DECK_SIZE_WARN_MB` | `50` | orange badge / "manage" threshold |
| `CC_DECK_SIZE_CRIT_MB` | `100` | red badge / auto-prune threshold |
| `CC_DECK_SNAPSHOT_KEEP` | `3` | snapshots kept by `Ctrl-G` / auto-prune |
| `CC_DECK_TAIL_KEEP` | `10` | turns kept by `Ctrl-E` |
| `CC_DECK_LARGE_MAX` | `15` | max sessions shown in the manage group |
| `CC_DECK_DISABLE_AUTOPRUNE` | unset | set to disable auto snapshot-pruning |

---

## Files

| Path | Purpose |
|------|---------|
| `~/.claude/.cc-deck-cache.json` | mtime-based session cache |
| `~/.claude/.cc-deck-pins.json` | manually pinned sessions |
| `~/.claude/.cc-deck-mode` | last selected resume mode |
| `~/.claude/.cc-deck-quick.json` | quick session registry |
| `~/.cc-deck-quick/` | working directory for quick sessions |
| `~/.claude/_archive/` | gzip backups of sessions trimmed with `Ctrl-E` |
| `~/.claude/.cc-deck-last-update` | timestamp of last auto-update check |
| `~/.claude/.cc-deck-updated` | sentinel file for pending update notification |
| `~/.claude/.cc-deck-update.lock` | lock file to prevent concurrent updates |

---

## Made with Claude Code

[![Claude](https://img.shields.io/badge/Made%20with-Claude%20Code-orange)](https://claude.ai/code)
