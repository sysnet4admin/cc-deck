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
    if (-not $global:_CC_DECK.Python) {
        Write-Host "[cc-deck] Error: python not found. Install Python 3 from https://python.org"
        return
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

                $header = "${ESC}[1;33m[TODO]${ESC}[0m=auto-pinned  ${ESC}[1;35m[PIN]${ESC}[0m=manual | Enter: ${enterLabel}  ^K: pin  ^D: delete(TODO/PIN)  ^O/A/S/X: mode  ESC: quit"

                $result = $allEntries | fzf `
                    --ansi `
                    "--delimiter=`t" `
                    --with-nth=3 `
                    --height=60% `
                    --reverse `
                    "--prompt=cc-deck> " `
                    "--header=$header" `
                    --expect=ctrl-o,ctrl-a,ctrl-s,ctrl-x,ctrl-k,ctrl-d

                if (-not $result) { return }

                # fzf --expect: result[0]=key (empty=Enter), result[1]=selected line
                $resultArr = @($result)
                $key      = $resultArr[0]
                $selected = if ($resultArr.Count -gt 1) { $resultArr[1] } else { $resultArr[0] }
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

                # Mode switch keys
                switch ($key) {
                    "ctrl-o" { $mode = "default" }
                    "ctrl-a" { $mode = "api" }
                    "ctrl-s" { $mode = "dangerous" }
                    "ctrl-x" { $mode = "api-dangerous" }
                }

                $sessionId = $rawId -replace '^(TODO:|PIN:)', ''
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
