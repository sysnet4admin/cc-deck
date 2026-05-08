# cc-deck

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
메모리에 TODO로 기록해줘
다음 주에 다시 확인해줘
며칠 지켜보자
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

---

---

# cc-deck (한국어)

> Claude Code 세션 브라우저 & 태스크 관리 도구

여러 프로젝트를 오가며 Claude Code를 쓰다 보면 어떤 세션에서 뭘 하고 있었는지 파악하기 어렵습니다. `claude --resume`은 세션 목록을 보여주지만 요약이 압축되어 있어 어느 작업인지 구분하기 힘듭니다.

`cc-deck`은 fzf TUI로 전체 세션 히스토리를 탐색하며 각 세션의 **마지막 입력 내용**을 미리보기로 보여줍니다. Claude 메모리에 기록된 TODO는 자동으로 상단에 고정됩니다. 세션을 선택하면 원래 디렉토리로 자동 이동 후 재개합니다.

---

## 주요 기능

- **세션 브라우저** — 마지막 입력 내용 미리보기와 함께 fzf TUI로 탐색
- **TODO 자동 고정** — Claude 메모리에 기록된 TODO(`type: project`, `name: TODO...`)가 자동으로 상단에 표시
- **수동 고정** — `Ctrl-K`로 원하는 세션을 핀/언핀
- **스마트 재개** — 세션 선택 시 원래 디렉토리로 자동 이동 후 resume
- **4가지 실행 모드** — `claude`, `claude-api`, `--dangerously-skip-permissions` 및 조합 선택 가능
- **모드 기억** — 마지막 선택한 모드가 다음 실행에도 유지
- **빠른 속도** — mtime 기반 캐시로 재실행 시 ~0.04초

---

## 요구사항

- macOS (Linux 지원 예정)
- zsh
- python3
- [fzf](https://github.com/junegunn/fzf) — `brew install fzf`

---

## 설치

```zsh
git clone https://github.com/sysnet4admin/cc-deck.git ~/cc-deck
cd ~/cc-deck
./install.sh
source ~/.zshrc
```

`install.sh`가 `~/.zshrc`에 source 라인을 자동으로 추가합니다.

---

## 사용법

```
cc-deck
```

### 키 바인딩

| 키 | 동작 |
|----|------|
| `Enter` | 마지막 저장된 모드로 재개 |
| `Ctrl-K` | 현재 세션 고정 / 해제 (토글) |
| `Ctrl-O` | `claude`로 재개 |
| `Ctrl-A` | `claude-api`로 재개 |
| `Ctrl-D` | `claude --dangerously-skip-permissions`로 재개 |
| `Ctrl-X` | `claude-api --dangerously-skip-permissions`로 재개 |
| `ESC` | 종료 |

### 기본 명령어 변경

```zsh
export CLAUDE_DECK_CMD="claude-api"
# 또는
export CLAUDE_DECK_CMD="claude --dangerously-skip-permissions"
```

---

## TODO 동작 방식

Claude에게 나중에 확인할 항목을 기록해달라고 하면:

```
메모리에 TODO로 기록해줘
다음 주에 다시 확인해줘
며칠 지켜보자
```

Claude가 `type: project`, `name: TODO - ...` 형식의 메모리 파일을 작성합니다. cc-deck은 이를 자동 감지해서 세션 목록 상단에 고정하고, `originSessionId`를 통해 해당 작업 세션으로 바로 이동할 수 있습니다.

---

## 저장 파일

| 경로 | 용도 |
|------|------|
| `~/.claude/.cc-deck-cache.json` | mtime 기반 세션 캐시 |
| `~/.claude/.cc-deck-pins.json` | 수동 고정 세션 목록 |
| `~/.claude/.cc-deck-mode` | 마지막 선택한 실행 모드 |
