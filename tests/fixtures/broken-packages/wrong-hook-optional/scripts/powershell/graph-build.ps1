#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build or refresh a graphify knowledge graph for a project.

.DESCRIPTION
    Behavioural counterpart of scripts/bash/graph-build.sh. Identical outcomes,
    identical exit codes, identical stdout key set — see
    specs/002-graph-build-command/contracts/build-script.md.

    This script delegates every part of graph construction to the graphify CLI.
    It implements no extraction, clustering, or rendering of its own, and never
    installs or upgrades graphify.

    Exit codes:
      0  built | current
      2  usage error, or `build` without -Confirmed
      3  nothing-to-examine   (NOT success)
      4  dependency-missing
      5  dependency-too-old   (below floor, at/above ceiling, or unparseable)
      6  already-running
      7  interrupted-state
      8  failed
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Mode,

    [string] $Path = '.',
    [string] $MinVersion = '0.9.9',
    [string] $MaxVersion = '0.10.0',
    [switch] $Full,
    [switch] $Confirmed,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Rest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExitUsage = 2
$ExitNothing = 3
$ExitMissing = 4
$ExitTooOld = 5
$ExitRunning = 6
$ExitInterrupted = 7
$ExitFailed = 8

$OutDir = 'graphify-out'
$ExtDir = Join-Path '.specify' (Join-Path 'extensions' 'llm-wiki-graphify')
$LockDir = Join-Path $ExtDir 'build.lock'

$script:LockHeld = $false

# ---------------------------------------------------------------------------
# Output helpers
#
# stdout carries machine-readable key=value lines only. Everything a human reads
# goes to stderr, including graphify's own output, passed through unmodified.
# ---------------------------------------------------------------------------

function Emit([string] $Key, [string] $Value) { Write-Output "$Key=$Value" }
function Note([string] $Message = '') { [Console]::Error.WriteLine($Message) }

function Show-Usage {
    Note @'
Usage:
  graph-build.ps1 check  [-Path <p>] [-MinVersion <v>] [-MaxVersion <v>]
  graph-build.ps1 scope  [-Path <p>]
  graph-build.ps1 build  -Confirmed [-Path <p>] [-Full]
  graph-build.ps1 status [-Path <p>]

`build` refuses to run without -Confirmed. The flag is the caller asserting that
a human authorised this run; it is not a convenience bypass.
'@
}

function Release-Lock {
    if ($script:LockHeld) {
        Remove-Item -Recurse -Force $LockDir -ErrorAction SilentlyContinue
        $script:LockHeld = $false
    }
}

function Stop-With([int] $Code, [string] $Outcome) {
    if ($Outcome) { Emit 'outcome' $Outcome }
    Release-Lock
    exit $Code
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------

if (-not $Mode) { Show-Usage; exit $ExitUsage }

if ($Mode -notin @('check', 'scope', 'build', 'status')) {
    Note "unknown mode: $Mode"
    Show-Usage
    exit $ExitUsage
}

if ($Rest -and $Rest.Count -gt 0) {
    # Never ignored. A silently dropped -Full produces a refresh the caller
    # believes was a rebuild.
    Note "unknown argument: $($Rest -join ' ')"
    Show-Usage
    exit $ExitUsage
}

if ($Mode -eq 'build' -and -not $Confirmed) {
    Note 'build requires -Confirmed: the caller must assert that a human authorised this run'
    exit $ExitUsage
}

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

function Resolve-Root {
    $projectRoot = (Get-Location).ProviderPath

    if (-not (Test-Path -PathType Container $Path)) {
        Note "scope root does not exist: $Path"
        exit $ExitUsage
    }

    $resolved = (Resolve-Path $Path).ProviderPath

    if ($resolved -ne $projectRoot -and -not $resolved.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar)) {
        Note "scope root escapes the project root: $resolved"
        exit $ExitUsage
    }

    return $resolved
}

# ---------------------------------------------------------------------------
# Version handling
# ---------------------------------------------------------------------------

function Get-ParsedVersion([string] $Raw) {
    $match = [regex]::Match($Raw, '\b(\d+)\.(\d+)\.(\d+)\b')
    if (-not $match.Success) { return $null }
    return $match.Value
}

function Test-VersionLess([string] $A, [string] $B) {
    $left = $A.Split('.')
    $right = $B.Split('.')
    for ($i = 0; $i -lt 3; $i++) {
        $l = [int] $left[$i]
        $r = [int] $right[$i]
        if ($l -lt $r) { return $true }
        if ($l -gt $r) { return $false }
    }
    return $false
}

function Test-Dependency {
    if (-not (Get-Command graphify -ErrorAction SilentlyContinue)) {
        Note 'graphify is not installed, or is not on PATH.'
        Note ''
        Note 'This extension delegates all graph construction to graphify and never'
        Note 'installs it for you. To install it:'
        Note ''
        Note '    uv tool install graphifyy'
        Note '    # or: python3 -m pip install graphifyy'
        Note ''
        Note 'Then re-run this command. Nothing was written.'
        Stop-With $ExitMissing 'dependency-missing'
    }

    $raw = (& graphify --version 2>&1 | Select-Object -First 1) -as [string]
    $parsed = Get-ParsedVersion $raw

    # Fail closed. The version string's own format is unversioned and could
    # change; an unparseable version is never treated as new enough.
    if (-not $parsed) {
        Note 'could not parse a version from graphify --version'
        Note "  output was: $raw"
        Note "  required:   >=$MinVersion,<$MaxVersion"
        Stop-With $ExitTooOld 'dependency-too-old'
    }

    if (Test-VersionLess $parsed $MinVersion) {
        Note "graphify $parsed is older than this extension supports."
        Note "  found:    $parsed"
        Note "  required: >=$MinVersion,<$MaxVersion"
        Stop-With $ExitTooOld 'dependency-too-old'
    }

    if (-not (Test-VersionLess $parsed $MaxVersion)) {
        Note "graphify $parsed is newer than this extension has been verified against."
        Note "  found:    $parsed"
        Note "  required: >=$MinVersion,<$MaxVersion"
        Note ''
        Note 'graphify is pre-1.0 and promises no compatibility between minor versions.'
        Note "This extension reads fields observed in $MinVersion; a newer release may"
        Note 'have changed them. Proceeding could silently report a wrong graph.'
        Stop-With $ExitTooOld 'dependency-too-old'
    }

    return $parsed
}

# ---------------------------------------------------------------------------
# Locking
#
# The lock lives in the extension's own directory, never under graphify-out/,
# which the tool owns. Creating a directory is atomic on Windows filesystems as
# it is on POSIX; a check-then-create lock file is not.
# ---------------------------------------------------------------------------

function Test-ProcessAlive([string] $ProcessId) {
    if (-not $ProcessId) { return $false }
    try {
        $null = Get-Process -Id ([int] $ProcessId) -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Acquire-Lock {
    $pidFile = Join-Path $LockDir 'pid'

    try {
        $null = New-Item -ItemType Directory -Path $LockDir -ErrorAction Stop
        Set-Content -Path $pidFile -Value $PID
        $script:LockHeld = $true
        return
    } catch {
        # Directory already exists — inspect the owner.
    }

    $owner = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)

    if (Test-ProcessAlive $owner) {
        Note "another build is already running for this project (process $owner)."
        Note 'Nothing was written. Wait for it to finish, or stop it.'
        Stop-With $ExitRunning 'already-running'
    }

    # Stale lock. Without reclamation, a single crash would disable the command
    # permanently — a safety mechanism becoming an availability failure.
    $shown = if ($owner) { $owner } else { 'unknown' }
    Note "reclaiming a stale lock left by process $shown, which is no longer running."
    Remove-Item -Recurse -Force $LockDir -ErrorAction SilentlyContinue
    $null = New-Item -ItemType Directory -Path $LockDir -Force
    Set-Content -Path $pidFile -Value $PID
    $script:LockHeld = $true
}

# ---------------------------------------------------------------------------
# Graph inspection
#
# The edge array is named `links`, not `edges`. Reading `edges` returns nothing
# and reports a graph with zero relationships as a success.
# ---------------------------------------------------------------------------

function Get-GraphCounts([string] $GraphPath) {
    $graph = Get-Content -Raw -Path $GraphPath | ConvertFrom-Json

    $nodes = if ($graph.PSObject.Properties.Name -contains 'nodes') { @($graph.nodes) } else { @() }
    $links = if ($graph.PSObject.Properties.Name -contains 'links') { @($graph.links) } else { @() }

    $counts = @{}
    foreach ($link in $links) {
        $label = if ($link.PSObject.Properties.Name -contains 'confidence') { $link.confidence } else { 'UNLABELLED' }
        if ($counts.ContainsKey($label)) { $counts[$label]++ } else { $counts[$label] = 1 }
    }

    Emit 'entities' $nodes.Count
    Emit 'relationships' $links.Count
    foreach ($label in @('EXTRACTED', 'INFERRED', 'AMBIGUOUS')) {
        $value = if ($counts.ContainsKey($label)) { $counts[$label] } else { 0 }
        Emit "evidence_$label" $value
    }
    foreach ($label in ($counts.Keys | Sort-Object)) {
        if ($label -notin @('EXTRACTED', 'INFERRED', 'AMBIGUOUS')) {
            Emit "evidence_$label" $counts[$label]
        }
    }
}

function Get-CountValue([string] $GraphPath, [string] $Field) {
    $line = Get-GraphCounts $GraphPath | Where-Object { $_ -like "$Field=*" } | Select-Object -First 1
    if (-not $line) { return 0 }
    return [int] ($line -split '=', 2)[1]
}

function Test-Interrupted {
    # manifest.json records what the tool believed it had processed. That record
    # surviving without the graph it describes is what an interrupted run leaves.
    return (Test-Path (Join-Path $OutDir 'manifest.json')) -and
           -not (Test-Path (Join-Path $OutDir 'graph.json'))
}

function Get-FileCount([string] $Root) {
    return @(Get-ChildItem -Path $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "[\\/]$OutDir[\\/]" -and $_.FullName -notmatch '[\\/]\.git[\\/]' }).Count
}

function Get-LatestBackup {
    return (Get-ChildItem -Path $OutDir -Directory -Filter '20*' -ErrorAction SilentlyContinue |
        Sort-Object Name | Select-Object -Last 1)
}

# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------

function Invoke-Check {
    $version = Test-Dependency
    Emit 'outcome' 'dependency-ok'
    Emit 'graphify_version' $version
    Emit 'version_range' ">=$MinVersion,<$MaxVersion"
}

function Invoke-Scope {
    $root = Resolve-Root
    $files = Get-FileCount $root

    Emit 'outcome' 'scope'
    Emit 'root' $root
    Emit 'files' $files
    Emit 'exclusions' 'none'
    Emit 'coverage' 'structural'

    Note "This build will examine $files file(s) under $root."
    Note ''
    Note 'No exclusions are applied. graphify offers no exclusion mechanism, so'
    Note 'everything inside the scope root is read — including vendored code and'
    Note 'any secrets stored in files. Narrow the scope root if that matters.'
    Note ''
    Note 'Structure is extracted from code and documents alike. The semantic layer —'
    Note 'concepts spanning documents, and inferred relationships — requires a separate'
    Note 'model-assisted pass; see the build report for the handoff.'
}

function Invoke-Status {
    $root = Resolve-Root
    $graph = Join-Path $root (Join-Path $OutDir 'graph.json')

    Emit 'outcome' 'status'

    if (-not (Test-Path $graph)) {
        Emit 'graph_present' 'no'
        Note "No graph has been built for $root."
        Note 'Run the build command to create one. Absence is a state, not an error.'
        return
    }

    Emit 'graph_present' 'yes'
    Get-GraphCounts $graph
    Emit 'output' (Join-Path $root $OutDir)
}

function Invoke-Build {
    $null = Test-Dependency
    $root = Resolve-Root

    $null = New-Item -ItemType Directory -Path $ExtDir -Force
    Acquire-Lock

    Push-Location $root
    try {
        # graphify writes graphify-out/manifest.json into the WORKING directory
        # while writing the graph to the target path. Entering the scope root
        # first collapses the two locations into one.

        if ((Test-Interrupted) -and -not $Full) {
            Note "a previous build left an incomplete graph: $OutDir/manifest.json exists"
            Note "but $OutDir/graph.json does not."
            Note ''
            Note 'Refusing to refresh from an incomplete state. Re-run with -Full to'
            Note 'rebuild from the sources — that is the recovery path, and it works from'
            Note 'this state by design.'
            Stop-With $ExitInterrupted 'interrupted-state'
        }

        $graph = Join-Path $OutDir 'graph.json'
        $prevEntities = 0
        $prevRelationships = 0
        if (Test-Path $graph) {
            $prevEntities = Get-CountValue $graph 'entities'
            $prevRelationships = Get-CountValue $graph 'relationships'
        }

        if ($Full) {
            # There is no --full flag on graphify, and --force is not equivalent:
            # it leaves outputs untouched on an unchanged corpus. Removing
            # graph.json forces a rebuild. Exactly one derived file is deleted so
            # the tool regenerates it — cache/, manifest.json, and the dated
            # backups survive, because removing those would turn a rebuild into
            # data loss.
            Note "full rebuild: removing $graph so graphify regenerates it"
            Remove-Item -Force $graph -ErrorAction SilentlyContinue
        }

        $started = Get-Date
        $toolOut = (& graphify update . 2>&1 | Out-String)
        $toolStatus = $LASTEXITCODE
        $elapsed = [int] ((Get-Date) - $started).TotalSeconds

        # graphify's own output goes through unmodified. A failure is never absorbed.
        Note $toolOut.TrimEnd()

        # Classify from the tool's own output, never from a file count. A count
        # cannot distinguish "no files" from "files the tool does not read", and
        # the set it reads is wider than expected: document structure counts.
        if ($toolOut -match 'No code files found') {
            Note "nothing to examine under $root — graphify found no readable files."
            Note 'This is not a successful build. No graph was produced.'
            Stop-With $ExitNothing 'nothing-to-examine'
        }

        if ($toolStatus -ne 0) {
            Note "graphify exited with status $toolStatus. The graph was not updated."
            Stop-With $ExitFailed 'failed'
        }

        if (-not (Test-Path $graph)) {
            Note "graphify reported success but produced no $graph."
            Stop-With $ExitFailed 'failed'
        }

        if ($toolOut -match 'No code-graph topology changes detected') {
            Emit 'outcome' 'current'
        } else {
            Emit 'outcome' 'built'
        }

        Get-GraphCounts $graph
        Emit 'output' (Join-Path $root $OutDir)
        Emit 'elapsed_seconds' $elapsed
        Emit 'coverage' 'structural'
        Emit 'exclusions' 'none'

        Emit 'delta_entities' ((Get-CountValue $graph 'entities') - $prevEntities)
        Emit 'delta_relationships' ((Get-CountValue $graph 'relationships') - $prevRelationships)

        $backup = Get-LatestBackup
        if ($backup) {
            Emit 'backup' (Join-Path $root (Join-Path $OutDir $backup.Name))
            Note ''
            Note "graphify kept a backup of the previous graph at $($backup.Name)."
            Note 'It is the only recovery path if this rebuild was a mistake.'
        }

        Note ''
        Note 'Coverage: structure was extracted from code and from documents alike — a'
        Note 'Markdown heading is an entity here, exactly as a function is. What this run'
        Note 'did NOT produce is the semantic layer: concepts spanning documents, and'
        Note 'relationships inferred between prose and the code implementing it. Those come'
        Note 'from the model-assisted pass — run /graphify --update in your AI assistant.'
        Note 'No exclusions were applied; everything under the scope root was read.'
    } finally {
        Pop-Location
        Release-Lock
    }
}

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Configuration
#
# Behavioural counterpart of load_config in the bash variant. A missing config is
# silent and defaulted; a malformed config stops with config-invalid rather than
# defaulting silently. Precedence: command-line argument, then config, then the
# compiled default — so a config value applies only where the argument still holds
# its default.
# ---------------------------------------------------------------------------

function Load-Config {
    $config = Join-Path $ExtDir 'config.yml'
    if (-not (Test-Path $config)) { return }

    $cfgRoot = $null
    $cfgMin = $null
    $cfgMax = $null
    $section = $null

    foreach ($raw in Get-Content -Path $config) {
        $line = ($raw -split '#', 2)[0].TrimEnd()
        if (-not $line.Trim()) { continue }

        if ($line -notmatch '^\s') {
            $section = ($line -split ':', 2)[0].Trim()
            continue
        }

        if ($line -notmatch ':') {
            Note "config file is malformed: $config"
            Note '  malformed line (no colon)'
            Note ''
            Note 'Refusing to fall back to defaults — that would run the build in a way you'
            Note 'did not configure and could not see. Fix the file, or remove it to use'
            Note 'defaults deliberately.'
            Stop-With $ExitUsage 'config-invalid'
        }

        $parts = $line.Split(':', 2)
        $key = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"').Trim("'")

        switch ("$section.$key") {
            'scope.root' { $cfgRoot = $value }
            'graphify.min_version' { $cfgMin = $value }
            'graphify.max_version' { $cfgMax = $value }
        }
    }

    if ($cfgRoot -and $Path -eq '.') { $script:Path = $cfgRoot }
    if ($cfgMin -and $MinVersion -eq '0.9.9') { $script:MinVersion = $cfgMin }
    if ($cfgMax -and $MaxVersion -eq '0.10.0') { $script:MaxVersion = $cfgMax }
}

try {
    Load-Config

    switch ($Mode) {
        'check' { Invoke-Check }
        'scope' { Invoke-Scope }
        'build' { Invoke-Build }
        'status' { Invoke-Status }
    }
} finally {
    Release-Lock
}
