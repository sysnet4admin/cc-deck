# cc-deck

**[🇺🇸 English](README.md)**

> Claude Code 세션 브라우저 & 태스크 관리 도구

![데모](demo/demo_ko.gif)

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

### 세션 목록

```
[TODO] /tmp/projects/infra/k8s: 3Gi 적용 후 2주간 OOMKill 재발 여부 모니터링
[PIN]  /tmp/projects/api-server: 롤백 없이 어떻게 수정해?
────────────────────────────────────────────────────────────────────────
* 2026-05-08 09:14  /tmp/projects/api-server:    롤백 없이 어떻게 수정해?
  2026-05-08 08:59  /tmp/projects/infra/k8s:    적용했어 — OOMKill 다시 나면 알려줘
  2026-05-08 08:38  /tmp/projects/frontend:     수정 방법이 뭐야?
  2026-05-08 08:17  /tmp/projects/auth-service: 토큰 폐기는 어떻게 해?
  2026-05-08 07:59  /tmp/projects/monitoring:   에러율 알림도 추가해줘
```

- `*` 현재 디렉토리 표시
- `[TODO]` Claude 메모리에서 자동 감지 (`type: project`, 이름이 `TODO`로 시작)
- `[PIN]` `Ctrl-K`로 수동 고정한 세션

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

---

## Made with Claude Code

[![Claude](https://img.shields.io/badge/Made%20with-Claude%20Code-orange)](https://claude.ai/code)
