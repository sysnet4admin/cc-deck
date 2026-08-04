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

# Snapshot pruning (lossless: drops old file-history-snapshot entries)
function _cc_deck_prune {
    & $global:_CC_DECK.Python "$($global:_CC_DECK.Dir)\lib\prune_snapshots.py" @args
}

# Tail-resume (lossy: keep recent turns, gzip-archive the full session)
function _cc_deck_tail {
    & $global:_CC_DECK.Python "$($global:_CC_DECK.Dir)\lib\tail_resume.py" @args
}

# Build session entries: session_id<TAB>cwd<TAB>display_line
# Oversized sessions are surfaced separately via load_pinned ([S_L]/[S_XL]
# group), so regular rows carry no size marker.
function _cc_deck_build_sessions {
    param($Files, $CurrentDir)
    $ESC = [char]0x1B
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (_cc_deck_extract_all $Files)) {
        $parts = $line -split "`t", 4
        if ($parts.Count -lt 3) { continue }
        $filepath = $parts[0]; $cwd = $parts[1]; $preview = $parts[2]
        $sessionId = [System.IO.Path]::GetFileNameWithoutExtension($filepath)
        try { $mtime = (Get-Item $filepath -ErrorAction Stop).LastWriteTime.ToString('yyyy-MM-dd HH:mm') }
        catch { continue }
        $shortCwd = if ($cwd -and $cwd.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
            '~' + $cwd.Substring($HOME.Length)
        } elseif ($cwd) { $cwd } else { '?' }
        $marker = if ($cwd -eq $CurrentDir) { "${ESC}[32m*${ESC}[0m " } else { "  " }
        $previewText = if ($preview) { $preview } else { "(no preview)" }
        $list.Add("${sessionId}`t${cwd}`t${marker}${mtime}  ${shortCwd}: ${previewText}")
    }
    # Comma prevents PowerShell from unrolling the collection; without it the
    # List[string] returns as Object[] and the caller's AddRange() type-fails.
    return ,$list
}

function _cc_deck_load_pinned {
    $env:COLUMNS = [string][Console]::WindowWidth   # full-width "manage" separator
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
        switch ($m) {
            { $_ -in 'default','api','dangerous','api-dangerous' } { return $m }
            'claude+skip'     { return 'dangerous' }
            'claude-api+skip' { return 'api-dangerous' }
            'claude-api'      { return 'api' }
        }
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
    $uuidPattern = '(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    if ($SessionId -notmatch "^${uuidPattern}$") {
        $m = [regex]::Match($SessionId, $uuidPattern)
        if ($m.Success) { $SessionId = $m.Value }
    }
    if (-not $SessionId) { Write-Host "[cc-deck] ERROR: empty session ID"; return }
    $currentDir = (Get-Location).Path

    if ($Cwd -and ($Cwd -ne $currentDir)) {
        if (Test-Path -LiteralPath $Cwd -PathType Container) {
            $shortCwd = if ($Cwd.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
                '~' + $Cwd.Substring($HOME.Length)
            } else { $Cwd }
            Write-Host "cd $shortCwd"
            Set-Location -LiteralPath $Cwd
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
            else                      { claude --resume $SessionId }
        }
    }
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Host "[cc-deck] claude exited with code $LASTEXITCODE (session: $SessionId)"
    }
}

# ── cc-deck ────────────────────────────────────────────────────────────────────
# Browse all Claude Code sessions via fzf TUI and resume selected.
# TODOs from Claude memory and manually pinned sessions appear at the top.
#
# Keys:
#   Enter    resume with last saved mode
#   Ctrl-K   pin / unpin current session (toggle)
#   Ctrl-R   delete selected TODO or PIN entry
#   Ctrl-O   resume with: claude
#   Ctrl-A   resume with: claude-api
#   Ctrl-S   resume with: claude --dangerously-skip-permissions
#   Ctrl-X   resume with: claude-api --dangerously-skip-permissions
#   F1       show key bindings help
#
# Env:
#   CLAUDE_DECK_CMD   override default resume command
function cc-deck {
    param([string]$Subcommand)

    if (-not $global:_CC_DECK.Python) {
        Write-Host "[cc-deck] Error: python not found. Install Python 3 from https://python.org"
        return
    }

    # 'cc-deck -q/--quick [prompt]' — ephemeral query, no session kept
    if ($Subcommand -eq '-q' -or $Subcommand -eq '--quick') {
        $prompt = $args -join ' '
        if ($prompt) {
            claude -p --no-session-persistence $prompt
        } else {
            # Interactive ephemeral session: start claude, delete session on exit
            $marker = [System.IO.Path]::GetTempFileName()
            $markerTime = (Get-Item $marker).LastWriteTime
            $claudeCmd = if ($env:CLAUDE_DECK_CMD) { $env:CLAUDE_DECK_CMD } else { "claude" }
            & $claudeCmd
            Get-ChildItem "$HOME\.claude\projects" -Filter "*.jsonl" -Recurse -Depth 2 |
                Where-Object { $_.FullName -notmatch '[\\/]subagents[\\/]' -and $_.LastWriteTime -gt $markerTime } |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Remove-Item $marker -ErrorAction SilentlyContinue
        }
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
        # Switch everything to UTF-8 (no-BOM) so fzf receives Korean correctly.
        # [System.Text.Encoding]::UTF8 emits BOM in PS5.1/.NET4; use the explicit no-BOM constructor.
        chcp 65001 | Out-Null
        $noBomUtf8                 = [System.Text.UTF8Encoding]::new($false)
        $OutputEncoding            = $noBomUtf8
        [Console]::OutputEncoding = $noBomUtf8
        [Console]::InputEncoding  = $noBomUtf8

        $currentDir = (Get-Location).Path
        $defaultCmd = if ($env:CLAUDE_DECK_CMD) { $env:CLAUDE_DECK_CMD } else { "claude" }

        # Compute available modes: CC_DECK_MODES > ANTHROPIC_API_KEY > default only
        # Detect api config in PowerShell profile, excluding comment lines
        $apiPatterns = 'ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_BASE_URL'
        $rcFiles = @($PROFILE, "$HOME\.bashrc", "$HOME\.bash_profile") | Where-Object { Test-Path $_ }
        $apiInRc = $rcFiles | ForEach-Object {
            Get-Content $_ -ErrorAction SilentlyContinue |
                Where-Object { $_ -notmatch '^\s*#' } |
                Where-Object { $_ -match $apiPatterns }
        } | Select-Object -First 1

        $availableModes = if ($env:CC_DECK_MODES) {
            $env:CC_DECK_MODES -split ',' | ForEach-Object { $_.Trim() }
        } elseif ($env:ANTHROPIC_API_KEY -or $env:ANTHROPIC_AUTH_TOKEN -or $apiInRc) {
            @('default','api','dangerous','api-dangerous')
        } else {
            @('default','dangerous')
        }
        $env:_CC_DECK_AVAILABLE_MODES = $availableModes -join ','

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

        # Auto snapshot-prune: losslessly shrink oversized sessions before listing.
        # Scans ALL sessions (not just the recent 100 shown) — bloated files are
        # usually old/unlisted. Conversation lines and original mtime are preserved.
        if (-not $env:CC_DECK_DISABLE_AUTOPRUNE) {
            $keepN = if ($env:CC_DECK_SNAPSHOT_KEEP) { $env:CC_DECK_SNAPSHOT_KEEP } else { 3 }
            $critMb = if ($env:CC_DECK_SIZE_CRIT_MB) { $env:CC_DECK_SIZE_CRIT_MB } else { 100 }
            # Pass the projects dir as a single --root argument; Python walks it.
            # Avoids PowerShell→native stdin piping and command-line length limits.
            _cc_deck_prune scan-prune --root $projectsDir --keep $keepN --threshold-mb $critMb
        }

        # Entries rebuilt after a Ctrl-G prune (oversized sessions surfaced via
        # load_pinned's [S_L]/[S_XL] group, so regular rows carry no marker).
        $sessionEntries = _cc_deck_build_sessions $files $currentDir
        $sessDirty = $false

        if ($sessionEntries.Count -eq 0) {
            Write-Host "[cc-deck] no sessions found"
            return
        }

        $hasFzf = $null -ne (Get-Command fzf -ErrorAction SilentlyContinue)

        if ($hasFzf) {
            $sessionId = $null
            $cwd       = $null
            $ESC       = [char]0x1B

            # Env vars for fzf transform/execute (runs via cmd.exe, expands %VAR%)
            $env:_CC_DECK_PY    = $global:_CC_DECK.Python
            $env:_CC_DECK_CYCLE = "`"$($global:_CC_DECK.Dir)\lib\cycle_mode.py`""
            $env:_CC_DECK_HELP  = "`"$($global:_CC_DECK.Dir)\lib\show_help.py`""
            $env:_CC_DECK_QUICK = "`"$($global:_CC_DECK.Dir)\lib\quick_query.py`""

            while ($true) {
                # Sync mode from file; reset if no longer available
                $mode = if ($env:CLAUDE_DECK_CMD) { "default" } else {
                    $m = _cc_deck_load_mode
                    if ($availableModes -notcontains $m) { $m = $availableModes[0]; _cc_deck_save_mode $m }
                    $m
                }

                # Rebuild session entries when dirty (after a Ctrl-G prune)
                if ($sessDirty) {
                    $sessionEntries = _cc_deck_build_sessions $files $currentDir
                    $sessDirty = $false
                }

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

                $modeColor = switch ($mode) {
                    "api"           { "${ESC}[1;34m" }
                    "dangerous"     { "${ESC}[1;31m" }
                    "api-dangerous" { "${ESC}[1;36m" }
                    default         { "${ESC}[1;38;2;217;119;87m" }
                }
                $modeLabel = switch ($mode) {
                    "api"           { "claude-api" }
                    "dangerous"     { "claude+skip" }
                    "api-dangerous" { "claude-api+skip" }
                    default         { $defaultCmd }
                }
                $header = "${ESC}[1;33m[TODO]${ESC}[0m=auto-pinned  ${ESC}[1;35m[PIN]${ESC}[0m=manual | ^K: pin  ^R: rm  ^Q: ask  ^G: prune  ^E: trim  Tab: cycle  F1: help | ${modeColor}[${modeLabel}]${ESC}[0m"

                $result = $allEntries | fzf `
                    --ansi `
                    "--delimiter=`t" `
                    --with-nth=3 `
                    --height=60% `
                    --reverse `
                    "--prompt=cc-deck> " `
                    "--header=$header" `
                    "--bind=tab:transform:%_CC_DECK_PY% %_CC_DECK_CYCLE%" `
                    "--bind=ctrl-q:execute(%_CC_DECK_PY% %_CC_DECK_QUICK%)" `
                    --expect=ctrl-o,ctrl-a,ctrl-s,ctrl-x,ctrl-k,ctrl-r,ctrl-g,ctrl-e,f1,ctrl-m

                if (-not $result) { return }

                # fzf --expect: first line=key (empty=Enter), second line=selected item.
                # PowerShell sometimes drops the empty first line on Enter, so detect by content.
                $resultArr = @($result)
                $knownKeys = @('ctrl-o','ctrl-a','ctrl-s','ctrl-x','ctrl-k','ctrl-r','ctrl-g','ctrl-e','f1','ctrl-m')
                if ($resultArr.Count -ge 2 -and ($resultArr[0] -in $knownKeys -or $resultArr[0] -eq '')) {
                    $key      = $resultArr[0]
                    $selected = $resultArr[1]
                } else {
                    $key      = ''
                    $selected = $resultArr[0]
                }
                # ctrl-m is Enter (0x0D); normalize to empty string so resume logic works
                if ($key -eq 'ctrl-m') { $key = '' }
                # F1: handle before $selected check (fzf may return empty selected for function keys)
                if ($key -eq 'f1') {
                    & $global:_CC_DECK.Python "$($global:_CC_DECK.Dir)\lib\show_help.py"
                    [Console]::Clear()
                    continue
                }
                if (-not $selected) { return }

                $parts = $selected -split "`t", 3
                $rawId = $parts[0].TrimStart([char]0xFEFF)   # strip BOM if PS5.1 pipe added one
                $cwd   = if ($parts.Count -gt 1) { $parts[1] } else { "" }

                if ($rawId -eq "SEP:") { continue }

                # Ctrl-G: prune old snapshots on the selected session (lossless, silent).
                # Works on TODO/PIN/large rows too (strip prefix → underlying session).
                # No output — the refreshed size in the manage group is the feedback.
                if ($key -eq "ctrl-g") {
                    $gid = $null
                    if ($rawId -like "QUICK:*" -or $rawId -eq "SEP:") { }
                    elseif ($rawId -like "TODO:*") { $gid = $rawId -replace '^TODO:', '' }
                    elseif ($rawId -like "PIN:*")  { $gid = $rawId -replace '^PIN:', '' }
                    else                           { $gid = $rawId }
                    if ($gid) {
                        $fp = Get-ChildItem -Path $projectsDir -Filter "$gid.jsonl" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                            Where-Object { $_.FullName -notmatch '[\\/]subagents[\\/]' } |
                            Select-Object -First 1 -ExpandProperty FullName
                        if ($fp) {
                            $keepN = if ($env:CC_DECK_SNAPSHOT_KEEP) { $env:CC_DECK_SNAPSHOT_KEEP } else { 3 }
                            _cc_deck_prune prune $fp --keep $keepN | Out-Null
                            $sessDirty = $true
                        }
                    }
                    continue
                }

                # Ctrl-E: tail-resume — trim to recent turns (LOSSY; archives full first)
                if ($key -eq "ctrl-e") {
                    $tid = $null
                    if ($rawId -like "QUICK:*" -or $rawId -eq "SEP:") { }
                    elseif ($rawId -like "TODO:*") { $tid = $rawId -replace '^TODO:', '' }
                    elseif ($rawId -like "PIN:*")  { $tid = $rawId -replace '^PIN:', '' }
                    else                           { $tid = $rawId }
                    if ($tid) {
                        $tfp = Get-ChildItem -Path $projectsDir -Filter "$tid.jsonl" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                            Where-Object { $_.FullName -notmatch '[\\/]subagents[\\/]' } |
                            Select-Object -First 1 -ExpandProperty FullName
                        if ($tfp) {
                            [Console]::Clear()
                            $keepT = if ($env:CC_DECK_TAIL_KEEP) { $env:CC_DECK_TAIL_KEEP } else { 10 }
                            _cc_deck_tail dry-run $tfp --keep-turns $keepT
                            Write-Host ""
                            $ans = Read-Host "  Trim to recent turns? Full session is gzip-archived first. [y/N]"
                            if ($ans -eq 'y' -or $ans -eq 'Y') {
                                _cc_deck_tail trim $tfp --keep-turns $keepT | Out-Null
                                $sessDirty = $true
                            }
                        }
                    }
                    [Console]::Clear()
                    continue
                }

                # Ctrl-K: toggle pin and reopen fzf
                if ($key -eq "ctrl-k") {
                    $display = if ($parts.Count -gt 2) { $parts[2] } else { "" }
                    $preview = if ($display -match ': (.+)$') { $Matches[1] } else { "" }
                    if ($rawId -like "TODO:*") {
                        Write-Host "[cc-deck] TODO is managed by Claude memory"
                        Start-Sleep -Seconds 1
                    } elseif ($rawId -like "PIN:*") {
                        _cc_deck_toggle_pin ($rawId -replace '^PIN:', '') $cwd $preview
                        Start-Sleep -Milliseconds 800
                    } else {
                        _cc_deck_toggle_pin $rawId $cwd $preview
                        Start-Sleep -Milliseconds 800
                    }
                    [Console]::Clear()
                    continue
                }

                # Ctrl-R: mark TODO done or remove PIN
                if ($key -eq "ctrl-r") {
                    if ($rawId -like "TODO:*" -or $rawId -like "PIN:*") {
                        _cc_deck_delete $rawId
                        Start-Sleep -Milliseconds 500
                    }
                    [Console]::Clear()
                    continue
                }

                # Mode switch: only apply if mode is available
                switch ($key) {
                    "ctrl-o" { if ($availableModes -contains "default")       { $mode = "default" } }
                    "ctrl-a" { if ($availableModes -contains "api")           { $mode = "api" } }
                    "ctrl-s" { if ($availableModes -contains "dangerous")     { $mode = "dangerous" } }
                    "ctrl-x" { if ($availableModes -contains "api-dangerous") { $mode = "api-dangerous" } }
                    default  { if (-not $env:CLAUDE_DECK_CMD) { $mode = _cc_deck_load_mode } }
                }

                $sessionId = $rawId -replace '^(TODO:|PIN:)', ''
                # If result still isn't a bare UUID, extract UUID portion (case-insensitive)
                if ($sessionId -notmatch '(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
                    $m2 = [regex]::Match($sessionId, '(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
                    if ($m2.Success) { $sessionId = $m2.Value }
                    else { $sessionId = '' }
                }
                break
            }

            if ($sessionId) {
                _cc_deck_resume $sessionId $cwd $mode
            } else {
                Write-Host "[cc-deck] could not extract session ID (rawId='$rawId')"
            }

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
