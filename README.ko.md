# cc-deck

**[🇺🇸 English](README.md)**

> Claude Code 세션 허브 — 원하는 세션을 바로 찾고, 추적하고, 재개

![데모](demo/demo_readme_ko.gif)

여러 프로젝트에서 Claude Code 세션이 쌓입니다. 어제 디버깅하던 세션, Claude가 나중에 확인하라고 기록한 TODO, 북마크해둔 세션으로 돌아가려면 번거롭습니다.

`cc-deck`은 그 번거로움을 없애줍니다. 전체 Claude Code 세션을 퍼지 검색으로 탐색할 수 있는 TUI이며, Claude 메모리의 TODO가 자동으로 상단에 고정됩니다. macOS(zsh), Linux(bash), Windows(PowerShell) 모두 지원합니다.

---

## 주요 기능

- **퍼지 검색** — 마지막 입력 내용을 기준으로 실시간 필터링
- **TODO 자동 고정** — `name: TODO...` 형식의 Claude 메모리 항목이 자동으로 상단에 표시
- **수동 고정(PIN)** — `Ctrl-K`로 원하는 세션을 핀/언핀
- **스마트 재개** — 원래 디렉토리로 자동 이동 후 resume
- **4가지 실행 모드** — `claude`, `claude-api`, `--dangerously-skip-permissions` 및 조합
- **Tab 모드 순환** — Tab으로 실행 모드 순환; 현재 모드가 헤더에 표시
- **모드 기억** — 마지막 선택한 모드가 유지
- **자동 업데이트** — 매일 백그라운드에서 업데이트 확인; `cc-deck update`로 수동 업데이트
- **빠른 속도** — mtime 기반 캐시, 재실행 시 ~0.04초

---

## 요구사항

| | macOS | Windows | Linux |
|---|---|---|---|
| 쉘 | zsh | PowerShell 5.1+ | bash |
| Python | python3 | python (3.x) | python3 |
| fzf | `brew install fzf` | `winget install junegunn.fzf` | `apt/dnf install fzf` |

---

## 설치

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

또는 PowerShell 프로필(`$PROFILE`)에 직접 추가:

```powershell
. "$HOME\cc-deck\cc-deck.ps1"
```

---

## 사용법

```
cc-deck
```

수동 업데이트:

```
cc-deck update
```

### 키 바인딩

| 키 | 동작 |
|----|------|
| `Enter` | 마지막 저장된 모드로 재개 |
| `Tab` | 실행 모드 순환 (default → api → skip → api+skip) |
| `Ctrl-K` | 현재 세션 고정 / 해제 |
| `Ctrl-R` | TODO 완료 처리 / PIN 제거 |
| `Ctrl-O` | `claude`로 재개 |
| `Ctrl-A` | `claude-api`로 재개 |
| `Ctrl-S` | `claude --dangerously-skip-permissions`로 재개 |
| `Ctrl-X` | `claude-api --dangerously-skip-permissions`로 재개 |
| `F1` | 도움말 보기 |
| `ESC` | 종료 |

### 세션 목록

```
[TODO] /tmp/projects/infra/k8s: 3Gi 적용 후 2주간 OOMKill 재발 여부 모니터링
[PIN]  /tmp/projects/api-server: 배포 이후 메모리 사용량 계속 증가 — 원인 찾아줘
────────────────────────────────────────────────────────────────────────
* 2026-05-08 09:14  /tmp/projects/api-server:    배포 이후 메모리 사용량 계속 증가
  2026-05-08 08:59  /tmp/projects/infra/k8s:    스케일 업 후 pod OOMKill 계속 남
  2026-05-08 08:38  /tmp/projects/frontend:     로그인 폼 validation이 Safari에서만 깨짐
  2026-05-08 08:17  /tmp/projects/auth-service: 세션 토큰을 JWT로 리팩토링
  2026-05-08 07:59  /tmp/projects/monitoring:   결제 API용 Grafana SLO 알림 설정
```

- `*` 현재 디렉토리 표시
- `[TODO]` — Claude 메모리에서 자동 감지 (`type: project`, `name`에 `TODO` 포함)
- `[PIN]` — `Ctrl-K`로 수동 고정

### 기본 명령어 변경

**macOS / Linux:**
```bash
export CLAUDE_DECK_CMD="claude-api"
```

**Windows:**
```powershell
$env:CLAUDE_DECK_CMD = "claude-api"
```

---

## 튜토리얼

### 1. 퍼지 검색으로 세션 찾기

```
cc-deck
```

프롬프트에 `OOM`을 입력하면 해당 내용이 포함된 세션만 실시간으로 필터링됩니다. 선택하면 원래 디렉토리로 이동 후 바로 재개됩니다.

```
cc-deck> OOM
  2/100
  2026-05-08 08:59  /tmp/projects/infra/k8s: 스케일 업 후 pod OOMKill 계속 남
```

### 2. TODO로 작업 추적하기

Claude에게 나중에 확인할 항목을 기록해달라고 하면:

```
"메모리에 TODO로 기록해줘"
"다음 주에 다시 확인해줘"
```

Claude가 다음과 같은 메모리 파일을 작성합니다:

```yaml
name: TODO - EKS 클러스터 3Gi 메모리 제한 적용 후 모니터링
type: project
originSessionId: a40fabf4-...
```

다음에 `cc-deck`을 열면 이 항목이 자동으로 상단에 고정되어 있고, 원본 세션으로 바로 이동할 수 있습니다.

### 3. PIN으로 세션 북마크하기

TUI에서 원하는 세션으로 이동 후 `Ctrl-K`를 누릅니다. 마지막 입력 내용이 레이블로 저장되어 상단에 고정됩니다. 다시 `Ctrl-K`를 누르면 해제됩니다.

```
[PIN]  /tmp/projects/api-server: 배포 이후 메모리 사용량 계속 증가 — 원인 찾아줘
```

### 4. TODO 완료 처리

TODO가 해결되면 `Ctrl-R`를 누릅니다. cc-deck은 메모리 파일의 이름에서 `TODO`를 제거하고 `(completed)`를 추가합니다. 메모리 파일 자체는 보존되므로 Claude의 컨텍스트는 유지됩니다.

```
# 처리 전
name: TODO - EKS 클러스터 3Gi 메모리 제한 적용 후 모니터링

# Ctrl-R 후
name: EKS 클러스터 3Gi 메모리 제한 적용 후 모니터링 (completed)
```

---

## 저장 파일

| 경로 | 용도 |
|------|------|
| `~/.claude/.cc-deck-cache.json` | mtime 기반 세션 캐시 |
| `~/.claude/.cc-deck-pins.json` | 수동 고정 세션 목록 |
| `~/.claude/.cc-deck-mode` | 마지막 선택한 실행 모드 |
| `~/.claude/.cc-deck-last-update` | 마지막 자동 업데이트 확인 시각 |
| `~/.claude/.cc-deck-updated` | 업데이트 알림 전달용 센티넬 파일 |
| `~/.claude/.cc-deck-update.lock` | 동시 업데이트 방지 잠금 파일 |

---

## Made with Claude Code

[![Claude](https://img.shields.io/badge/Made%20with-Claude%20Code-orange)](https://claude.ai/code)
