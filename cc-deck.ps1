# cc-deck.ps1: Claude Code session browser and task manager (Windows/PowerShell port)
# https://github.com/sysnet4admin/cc-deck
#
# Usage: dot-source this file in $PROFILE
#   . "$HOME\cc-deck\cc-deck.ps1"
#
# Requirements: python (3.x), fzf (winget install junegunn.fzf)

# Force UTF-8 I/O between Python and PowerShell
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'

# Capture install directory at dot-source time
$global:_CC_DECK = @{
    Dir      = $PSScriptRoot
    ModeFile = "$HOME\.claude\.cc-deck-mode"
    PinsFile = "$HOME\.claude\.cc-deck-pins.json"
    Python   = $null
}

# Detect python executable
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    $global:_CC_DECK.Python = "python3"
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $global:_CC_DECK.Python = "python"
}

# ── Internal helpers ───────────────────────────────────────────────────────────

function _cc_deck_extract_all {
    param([string[]]$Files)
    $Files | & $global:_CC_DECK.Python "$($global:_CC_DECK.Dir)\lib\extract_all.py"
}

function _cc_deck_load_pinned {
    & $global:_CC_DECK.Python "$($global:_CC_DECK.Dir)\lib\load_pinned.py" $global:_CC_DECK.PinsFile
}

function _cc_deck_toggle_pin {
    param([string]$SessionId, [string]$Cwd, [string]$Preview)
    & $global:_CC_DECK.Python "$($global:_CC_DECK.Dir)\lib\toggle_pin.py" $SessionId $Cwd $global:_CC_DECK.PinsFile $Preview
}

function _cc_deck_delete {
    param([string]$RawId)
    & $global:_CC_DECK.Python "$($global:_CC_DECK.Dir)\lib\delete_entry.py" $RawId $global:_CC_DECK.PinsFile
}

function _cc_deck_save_mode {
    param([string]$Mode)
    Set-Content -Path $global:_CC_DECK.ModeFile -Value $Mode -NoNewline -ErrorAction SilentlyContinue
}

function _cc_deck_load_mode {
    try {
        $m = (Get-Content $global:_CC_DECK.ModeFile -Raw -ErrorAction Stop).Trim()
        if ($m) { return $m }
    } catch {}
    return "default"
}

function _cc_deck_resume {
    param([string]$SessionId, [string]$Cwd, [string]$Mode = "default")
    # Strip any TODO:/PIN: prefix that may have leaked through
    if ($SessionId.StartsWith('PIN:'))  { $SessionId = $SessionId.Substring(4) }
    if ($SessionId.StartsWith('TODO:')) { $SessionId = $SessionId.Substring(5) }
    $SessionId = $SessionId.Trim()
    # Final guard: if not a bare UUID (e.g. drive-letter prefix leaked in), extract UUID
    $uuidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    if ($SessionId -notmatch "^${uuidPattern}$") {
        $m = [regex]::Match($SessionId, $uuidPattern)
        if ($m.Success) { $SessionId = $m.Value }
    }
    if (-not $SessionId) { Write-Host "[cc-deck] ERROR: empty session ID"; return }
    $currentDir = (Get-Location).Path

    if ($Cwd -and ($Cwd -ne $currentDir)) {
        if (Test-Path $Cwd -PathType Container) {
            $shortCwd = if ($Cwd.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
                '~' + $Cwd.Substring($HOME.Length)
            } else { $Cwd }
            Write-Host "cd $shortCwd"
            Set-Location $Cwd
        } else {
            Write-Host "[cc-deck] WARNING: '$Cwd' is not accessible."
            Write-Host "[cc-deck] claude --resume requires the original directory to be reachable."
            Write-Host "[cc-deck] Mount the drive or navigate there manually, then run:"
            Write-Host "          claude --resume $SessionId"
            return
        }
    }

    _cc_deck_save_mode $Mode

    switch ($Mode) {
        "api"           { claude-api --resume $SessionId }
        "dangerous"     { claude --dangerously-skip-permissions --resume $SessionId }
        "api-dangerous" { claude-api --dangerously-skip-permissions --resume $SessionId }
        default {
            if ($env:CLAUDE_DECK_CMD) { & $env:CLAUDE_DECK_CMD --resume $SessionId }
            else { claude --resume $SessionId }
        }
    }
}

# ── cc-deck ────────────────────────────────────────────────────────────────────
# Browse all Claude Code sessions via fzf TUI and resume selected.
# TODOs from Claude memory and manually pinned sessions appear at the top.
#
# Keys:
#   Enter    resume with last saved mode
#   Ctrl-K   pin / unpin current session (toggle)
#   Ctrl-D   delete selected TODO or PIN entry
#   Ctrl-O   resume with: claude
#   Ctrl-A   resume with: claude-api
#   Ctrl-S   resume with: claude --dangerously-skip-permissions
#   Ctrl-X   resume with: claude-api --dangerously-skip-permissions
#
# Env:
#   CLAUDE_DECK_CMD   override default resume command
function cc-deck {
    param([string]$Subcommand)

    if (-not $global:_CC_DECK.Python) {
        Write-Host "[cc-deck] Error: python not found. Install Python 3 from https://python.org"
        return
    }

    # 'cc-deck update' — manual update trigger
    if ($Subcommand -eq 'update') {
        Write-Host "[cc-deck] Checking for updates..."
        & $global:_CC_DECK.Python "$($global:_CC_DECK.Dir)\lib\auto_update.py" $global:_CC_DECK.Dir --force
        $flag = "$HOME\.claude\.cc-deck-updated"
        if (Test-Path $flag) {
            $info = (Get-Content $flag -Raw -ErrorAction SilentlyContinue).Trim()
            Remove-Item $flag -ErrorAction SilentlyContinue
            Write-Host "[cc-deck] Updated ($info). Reload with: . `$PROFILE"
        } else {
            Write-Host "[cc-deck] Already up to date."
        }
        return
    }

    # Show pending update notification
    $updateFlag = "$HOME\.claude\.cc-deck-updated"
    if (Test-Path $updateFlag) {
        $info = (Get-Content $updateFlag -Raw -ErrorAction SilentlyContinue).Trim()
        Remove-Item $updateFlag -ErrorAction SilentlyContinue
        Write-Host "[cc-deck] Updated ($info). Reload with: . `$PROFILE"
    }

    # Background auto-update check (24h TTL, non-blocking)
    if (-not $env:CC_DECK_DISABLE_AUTOUPDATER -and $global:_CC_DECK.Python) {
        $updateScript = "$($global:_CC_DECK.Dir)\lib\auto_update.py"
        if (Test-Path $updateScript) {
            $psi = [System.Diagnostics.ProcessStartInfo]@{
                FileName               = $global:_CC_DECK.Python
                Arguments              = "`"$updateScript`" `"$($global:_CC_DECK.Dir)`""
                WindowStyle            = 'Hidden'
                CreateNoWindow         = $true
                UseShellExecute        = $false
                RedirectStandardOutput = $true
                RedirectStandardError  = $true
            }
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        }
    }

    # Save current encoding state — PowerShell 5.1 pipes with ASCII by default, breaking Korean
    $savedChcp          = (chcp).Split(':')[-1].Trim()
    $savedOutputEnc     = $OutputEncoding
    $savedConsoleOutEnc = [Console]::OutputEncoding
    $savedConsoleInEnc  = [Console]::InputEncoding

    try {
        # Switch everything to UTF-8 so fzf receives Korean correctly
        chcp 65001 | Out-Null
        $OutputEncoding            = [System.Text.Encoding]::UTF8
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding  = [System.Text.Encoding]::UTF8

        $currentDir = (Get-Location).Path
        $defaultCmd = if ($env:CLAUDE_DECK_CMD) { $env:CLAUDE_DECK_CMD } else { "claude" }

        # Collect recent 100 session files sorted by last write time
        $projectsDir = "$HOME\.claude\projects"
        if (-not (Test-Path $projectsDir)) {
            Write-Host "[cc-deck] no sessions found (projects dir not found: $projectsDir)"
            return
        }

        $files = Get-ChildItem -Path $projectsDir -Filter "*.jsonl" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/]subagents[\\/]' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 100 |
            ForEach-Object { $_.FullName }

        if (-not $files) {
            Write-Host "[cc-deck] no sessions found"
            return
        }

        # Build session entries: session_id<TAB>cwd<TAB>display_line
        $sessionEntries = [System.Collections.Generic.List[string]]::new()
        $extracted = _cc_deck_extract_all $files
        foreach ($line in $extracted) {
            $parts = $line -split "`t", 3
            if ($parts.Count -lt 3) { continue }
            $filepath  = $parts[0]
            $cwd       = $parts[1]
            $preview   = $parts[2]

            $sessionId = [System.IO.Path]::GetFileNameWithoutExtension($filepath)
            try { $mtime = (Get-Item $filepath -ErrorAction Stop).LastWriteTime.ToString('yyyy-MM-dd HH:mm') }
            catch { continue }

            $shortCwd = if ($cwd -and $cwd.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
                '~' + $cwd.Substring($HOME.Length)
            } elseif ($cwd) { $cwd } else { '?' }

            $ESC    = [char]0x1B
            $marker = if ($cwd -eq $currentDir) { "${ESC}[32m*${ESC}[0m " } else { "  " }
            $previewText = if ($preview) { $preview } else { "(no preview)" }
            $sessionEntries.Add("${sessionId}`t${cwd}`t${marker}${mtime}  ${shortCwd}: ${previewText}")
        }

        if ($sessionEntries.Count -eq 0) {
            Write-Host "[cc-deck] no sessions found"
            return
        }

        # Resolve mode
        $savedMode = if ($env:CLAUDE_DECK_CMD) { "default" } else { _cc_deck_load_mode }
        $mode = $savedMode

        $enterLabel = switch ($savedMode) {
            "api"           { "claude-api" }
            "dangerous"     { "skip-permissions" }
            "api-dangerous" { "api+skip" }
            default         { $defaultCmd }
        }

        $hasFzf = $null -ne (Get-Command fzf -ErrorAction SilentlyContinue)

        if ($hasFzf) {
            $sessionId = $null
            $cwd       = $null
            $ESC       = [char]0x1B

            while ($true) {
                # Rebuild pinned entries (reflects state changes from Ctrl-K)
                $pinnedEntries = [System.Collections.Generic.List[string]]::new()
                $pinned = _cc_deck_load_pinned
                foreach ($line in $pinned) {
                    if (($line -split "`t").Count -ge 3) { $pinnedEntries.Add($line) }
                }

                $allEntries = [System.Collections.Generic.List[string]]::new()
                if ($pinnedEntries.Count -gt 0) {
                    $allEntries.AddRange($pinnedEntries)
                    $sep = [string]::new([char]0x2500, [Console]::WindowWidth - 1)
                $allEntries.Add("SEP:`t`t$sep")
                }
                $allEntries.AddRange($sessionEntries)

                $header = "${ESC}[1;33m[TODO]${ESC}[0m=auto-pinned  ${ESC}[1;35m[PIN]${ESC}[0m=manual | Enter: ${enterLabel}  Tab: mode  ^K: pin  ^D: del  ^/: help  ESC: quit"

                $result = $allEntries | fzf `
                    --ansi `
                    "--delimiter=`t" `
                    --with-nth=3 `
                    --height=60% `
                    --reverse `
                    "--prompt=cc-deck> " `
                    "--header=$header" `
                    "--bind=ctrl-d:accept" `
                    --expect=ctrl-o,ctrl-a,ctrl-s,ctrl-x,ctrl-k,ctrl-d,tab,ctrl-/

                if (-not $result) { return }

                # fzf --expect: first line=key (empty=Enter), second line=selected item.
                # PowerShell sometimes drops the empty first line on Enter, so detect by content.
                $resultArr = @($result)
                $knownKeys = @('ctrl-o','ctrl-a','ctrl-s','ctrl-x','ctrl-k','ctrl-d','tab','ctrl-/')
                if ($resultArr.Count -ge 2 -and ($resultArr[0] -in $knownKeys -or $resultArr[0] -eq '')) {
                    $key      = $resultArr[0]
                    $selected = $resultArr[1]
                } else {
                    $key      = ''
                    $selected = $resultArr[0]
                }
                if (-not $selected) { return }

                $parts = $selected -split "`t", 3
                $rawId = $parts[0]
                $cwd   = if ($parts.Count -gt 1) { $parts[1] } else { "" }

                if ($rawId -eq "SEP:") { continue }

                # Ctrl-K: toggle pin and reopen fzf
                if ($key -eq "ctrl-k") {
                    $display = if ($parts.Count -gt 2) { $parts[2] } else { "" }
                    $preview = if ($display -match ': (.+)$') { $Matches[1] } else { "" }
                    if ($rawId -like "TODO:*") {
                        Write-Host "[cc-deck] TODO is managed by Claude memory"
                        Start-Sleep -Seconds 1
                    } elseif ($rawId -like "PIN:*") {
                        _cc_deck_toggle_pin ($rawId -replace '^PIN:', '') $cwd $preview
                        Start-Sleep -Milliseconds 500
                    } else {
                        _cc_deck_toggle_pin $rawId $cwd $preview
                        Start-Sleep -Milliseconds 500
                    }
                    continue
                }

                # Ctrl-D: mark TODO done or remove PIN
                if ($key -eq "ctrl-d") {
                    if ($rawId -like "TODO:*" -or $rawId -like "PIN:*") {
                        _cc_deck_delete $rawId
                        Start-Sleep -Milliseconds 500
                    }
                    continue
                }

                # Tab: mode picker
                if ($key -eq "tab") {
                    $mk = @{
                        'default'       = if ($mode -eq 'default')       { "${ESC}[32m*${ESC}[0m" } else { " " }
                        'api'           = if ($mode -eq 'api')           { "${ESC}[32m*${ESC}[0m" } else { " " }
                        'dangerous'     = if ($mode -eq 'dangerous')     { "${ESC}[32m*${ESC}[0m" } else { " " }
                        'api-dangerous' = if ($mode -eq 'api-dangerous') { "${ESC}[32m*${ESC}[0m" } else { " " }
                    }
                    $modeChoices = @(
                        "default`t$($mk['default']) claude (default)         ^O   Normal Claude Code sessions"
                        "api`t$($mk['api']) claude-api               ^A   Alternative API endpoint"
                        "dangerous`t$($mk['dangerous']) skip-permissions         ^S   claude --dangerously-skip-permissions"
                        "api-dangerous`t$($mk['api-dangerous']) api + skip               ^X   claude-api --dangerously-skip-permissions"
                    )
                    $picked = $modeChoices | fzf `
                        --ansi `
                        "--delimiter=`t" `
                        --with-nth=2 `
                        --height=8 `
                        --reverse `
                        --no-sort `
                        "--prompt=mode> " `
                        "--header=Select resume mode  (Enter to apply, Esc to cancel)"
                    if ($picked) {
                        $mode = ($picked -split "`t")[0]
                        $enterLabel = switch ($mode) {
                            'api'           { 'claude-api' }
                            'dangerous'     { 'skip-permissions' }
                            'api-dangerous' { 'api+skip' }
                            default         { $defaultCmd }
                        }
                        _cc_deck_save_mode $mode
                    }
                    continue
                }

                # Ctrl-/: help
                if ($key -eq "ctrl-/") {
                    Write-Host ""
                    Write-Host "  cc-deck key bindings"
                    Write-Host "  $(([string]::new([char]0x2500, 54)))"
                    Write-Host "  Enter       Resume with current mode"
                    Write-Host "  Tab         Open mode picker (with descriptions)"
                    Write-Host "  Ctrl-O      Resume with: claude (default)"
                    Write-Host "  Ctrl-A      Resume with: claude-api"
                    Write-Host "  Ctrl-S      Resume with: claude --dangerously-skip-permissions"
                    Write-Host "  Ctrl-X      Resume with: claude-api --dangerously-skip-permissions"
                    Write-Host "  $(([string]::new([char]0x2500, 54)))"
                    Write-Host "  Ctrl-K      Pin / unpin session"
                    Write-Host "  Ctrl-D      Delete selected TODO or PIN"
                    Write-Host "  Ctrl-/      Show this help"
                    Write-Host "  ESC         Quit"
                    Write-Host ""
                    Write-Host "  Press any key to return..."
                    $null = [Console]::ReadKey($true)
                    continue
                }

                # Mode switch keys
                switch ($key) {
                    "ctrl-o" { $mode = "default" }
                    "ctrl-a" { $mode = "api" }
                    "ctrl-s" { $mode = "dangerous" }
                    "ctrl-x" { $mode = "api-dangerous" }
                }

                $sessionId = $rawId -replace '^(TODO:|PIN:)', ''
                # If result still isn't a bare UUID, extract UUID portion
                if ($sessionId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
                    $m2 = [regex]::Match($sessionId, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
                    if ($m2.Success) { $sessionId = $m2.Value }
                }
                break
            }

            if ($sessionId) { _cc_deck_resume $sessionId $cwd $mode }

        } else {
            # Fallback: numbered list when fzf is not installed
            Write-Host "[cc-deck] install fzf for TUI: winget install junegunn.fzf"
            Write-Host "[cc-deck] sessions:"
            $i = 1
            foreach ($entry in $sessionEntries) {
                $display = ($entry -split "`t", 3)[2]
                Write-Host "  [$i] $display"
                $i++
            }
            Write-Host ""
            $pick = Read-Host "select number (q to quit)"
            if (-not $pick -or $pick -eq "q") { return }
            if ($pick -notmatch '^\d+$' -or [int]$pick -lt 1 -or [int]$pick -gt $sessionEntries.Count) {
                Write-Host "invalid number"; return
            }
            $target  = $sessionEntries[[int]$pick - 1]
            $parts   = $target -split "`t", 3
            $rawId   = $parts[0]
            $cwd     = if ($parts.Count -gt 1) { $parts[1] } else { "" }
            if ($rawId -eq "SEP:") { return }
            $sessionId = $rawId -replace '^(TODO:|PIN:)', ''
            _cc_deck_resume $sessionId $cwd $mode
        }

    } finally {
        # Always restore encoding state
        chcp $savedChcp | Out-Null
        $OutputEncoding            = $savedOutputEnc
        [Console]::OutputEncoding = $savedConsoleOutEnc
        [Console]::InputEncoding  = $savedConsoleInEnc
    }
}
