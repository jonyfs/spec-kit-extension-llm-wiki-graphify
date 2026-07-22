#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Assert that the PowerShell graph build script fails correctly.

.DESCRIPTION
    The PowerShell counterpart of scripts/test-graph-build.sh, asserting the same
    contract: identical outcomes, identical exit codes, identical stdout keys.

    Constitution Principle XV: a gate that has only ever been observed passing has
    not been tested. Every failure state below is constructed deterministically —
    nothing depends on timing, because a test that flakes is a test that gets
    skipped.

    Parity between the two variants is proven by running both against the same
    fixtures, never by reading the two files side by side.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $RepoRoot 'extension/scripts/powershell/graph-build.ps1'
$Fixtures = Join-Path $RepoRoot 'tests/fixtures'

$Work = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
$null = New-Item -ItemType Directory -Path $Work -Force

$script:Passed = 0
$script:Failed = 0

function Pass([string] $Name) {
    Write-Host "  ok    $Name"
    $script:Passed++
}

function Fail([string] $Name, [string] $Detail) {
    Write-Host "  FAIL  $Name"
    Write-Host "        $Detail"
    $script:Failed++
}

# Runs the script and returns its stdout plus exit code. Both are checked:
# an exit code alone cannot tell two failures apart, and a stdout line alone
# proves nothing about whether the script actually stopped.
function Invoke-Target {
    param([string[]] $Arguments, [string] $WorkingDirectory = $null)

    $previous = Get-Location
    if ($WorkingDirectory) { Set-Location $WorkingDirectory }
    try {
        $stdout = & pwsh -NoProfile -File $Script @Arguments 2>$null
        return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($stdout -join "`n") }
    } finally {
        Set-Location $previous
    }
}

function Get-Field([string] $Out, [string] $Field) {
    $line = ($Out -split "`n") | Where-Object { $_ -like "$Field=*" } | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -split '=', 2)[1]
}

function Assert-Run {
    param([string] $Name, [int] $WantCode, [string] $WantOutcome, [string[]] $Arguments, [string] $In)

    $result = Invoke-Target -Arguments $Arguments -WorkingDirectory $In

    if ($result.Code -ne $WantCode) {
        Fail $Name "expected exit $WantCode, got $($result.Code)"
        return
    }
    if ($WantOutcome) {
        $got = Get-Field $result.Out 'outcome'
        if ($got -ne $WantOutcome) {
            Fail $Name "expected outcome=$WantOutcome, got outcome=$(if ($got) { $got } else { '<none>' })"
            return
        }
    }
    Pass $Name
}

function Assert-Field([string] $Name, [string] $Field, [string] $Want, [string] $Out) {
    $got = Get-Field $Out $Field
    if ($got -eq $Want) { Pass $Name } else {
        Fail $Name "expected $Field=$Want, got $Field=$(if ($got) { $got } else { '<none>' })"
    }
}

function Assert-Absent([string] $Name, [string] $Path) {
    if (Test-Path $Path) { Fail $Name "expected $Path not to exist, but it does" } else { Pass $Name }
}

function Assert-Present([string] $Name, [string] $Path) {
    if (Test-Path $Path) { Pass $Name } else { Fail $Name "expected $Path to exist, but it does not" }
}

# ---------------------------------------------------------------------------

Write-Host "`nUsage contract"

Assert-Run -Name 'build without -Confirmed exits 2' -WantCode 2 -WantOutcome '' -Arguments @('build')
Assert-Run -Name 'unknown mode exits 2' -WantCode 2 -WantOutcome '' -Arguments @('demolish')

Write-Host "`nDependency check"

# Absence is constructed, not assumed: PATH becomes an empty directory, so
# graphify cannot be found regardless of where it is installed.
$noPath = Join-Path $Work 'nopath'
$null = New-Item -ItemType Directory -Path $noPath -Force

$savedPath = $env:PATH
$pwshDir = Split-Path -Parent (Get-Command pwsh).Source
try {
    # pwsh itself must stay reachable, or the test fails for a reason that has
    # nothing to do with the script under test.
    $env:PATH = "$noPath$([IO.Path]::PathSeparator)$pwshDir"
    Assert-Run -Name 'missing dependency exits 4' -WantCode 4 -WantOutcome 'dependency-missing' `
        -Arguments @('check') -In $noPath
} finally {
    $env:PATH = $savedPath
}

Assert-Absent 'missing dependency creates no output directory' (Join-Path $noPath 'graphify-out')

if (-not (Get-Command graphify -ErrorAction SilentlyContinue)) {
    Write-Host "`ngraphify is not installed — build scenarios SKIPPED (not passed)."
    Write-Host "`n$($script:Passed) passed, $($script:Failed) failed, build scenarios skipped"
    if ($script:Failed -gt 0) { exit 1 }
    exit 0
}

Write-Host "`nEmpty scope"

$empty = Join-Path $Work 'empty'
$null = New-Item -ItemType Directory -Path $empty -Force
Set-Content -Path (Join-Path $empty '.gitkeep') -Value ''
Assert-Run -Name 'empty scope exits 3 as nothing-to-examine, not success' -WantCode 3 `
    -WantOutcome 'nothing-to-examine' -Arguments @('build', '-Confirmed') -In $empty

Write-Host "`nFirst build"

$code = Join-Path $Work 'code'
Copy-Item -Recurse (Join-Path $Fixtures 'graph-build-code') $code
$build = Invoke-Target -Arguments @('build', '-Confirmed') -WorkingDirectory $code

Assert-Field 'first build reports outcome=built' 'outcome' 'built' $build.Out
Assert-Field 'first build reports 5 entities' 'entities' '5' $build.Out
Assert-Field 'first build reports 7 relationships' 'relationships' '7' $build.Out
Assert-Field 'all 7 relationships are EXTRACTED' 'evidence_EXTRACTED' '7' $build.Out
Assert-Field 'coverage is reported as structural' 'coverage' 'structural' $build.Out
Assert-Present 'graph.json was produced' (Join-Path $code 'graphify-out/graph.json')

Write-Host "`nNo-change refresh"

$refresh = Invoke-Target -Arguments @('build', '-Confirmed') -WorkingDirectory $code
Assert-Field 'unchanged refresh reports outcome=current' 'outcome' 'current' $refresh.Out

Write-Host "`nFull rebuild"

$full = Invoke-Target -Arguments @('build', '-Confirmed', '-Full') -WorkingDirectory $code
Assert-Field 'full rebuild reports outcome=built' 'outcome' 'built' $full.Out
Assert-Present 'full rebuild preserves cache/' (Join-Path $code 'graphify-out/cache')
Assert-Present 'full rebuild preserves manifest.json' (Join-Path $code 'graphify-out/manifest.json')

Write-Host "`nInterrupted state"

Remove-Item -Force (Join-Path $code 'graphify-out/graph.json')
Assert-Run -Name 'interrupted state exits 7 and refuses to refresh' -WantCode 7 `
    -WantOutcome 'interrupted-state' -Arguments @('build', '-Confirmed') -In $code

$recover = Invoke-Target -Arguments @('build', '-Confirmed', '-Full') -WorkingDirectory $code
Assert-Field '-Full recovers from the interrupted state' 'outcome' 'built' $recover.Out

Write-Host "`nConcurrent build"

$lock = Join-Path $code '.specify/extensions/llm-wiki-graphify/build.lock'
$null = New-Item -ItemType Directory -Path $lock -Force
Set-Content -Path (Join-Path $lock 'pid') -Value $PID
Assert-Run -Name 'held lock exits 6 without writing' -WantCode 6 -WantOutcome 'already-running' `
    -Arguments @('build', '-Confirmed') -In $code

# A dead owner must be reclaimable, or one crash disables the command forever.
Set-Content -Path (Join-Path $lock 'pid') -Value '999999'
$stale = Invoke-Target -Arguments @('build', '-Confirmed') -WorkingDirectory $code
$staleOutcome = Get-Field $stale.Out 'outcome'
if ($staleOutcome -in @('built', 'current')) {
    Pass 'stale lock is reclaimed rather than blocking forever'
} else {
    Fail 'stale lock is reclaimed' "got outcome=$(if ($staleOutcome) { $staleOutcome } else { '<none>' })"
}

Write-Host "`nNon-default scope root"

$rooted = Join-Path $Work 'rooted'
$null = New-Item -ItemType Directory -Path (Join-Path $rooted 'sub/src') -Force
Set-Content -Path (Join-Path $rooted 'sub/src/s.py') -Value "def s():`n    return 1"
$null = Invoke-Target -Arguments @('build', '-Confirmed', '-Path', 'sub') -WorkingDirectory $rooted
Assert-Present 'graph lands under the scope root' (Join-Path $rooted 'sub/graphify-out/graph.json')
Assert-Absent 'no stray output beside the scope root' (Join-Path $rooted 'graphify-out')

# The lock must be RELEASED, not merely acquired. The concurrency assertions create
# their own lock, so they pass whether or not the script releases one. This is the
# case that catches a lock path resolved against the wrong directory — the defect
# the bash variant actually had, and which parity claims had been blind to.
Assert-Absent 'no lock remains after a build with a non-default scope root' `
    (Join-Path $rooted '.specify/extensions/llm-wiki-graphify/build.lock')
Assert-Absent 'no lock remains inside the scope root either' `
    (Join-Path $rooted 'sub/.specify/extensions/llm-wiki-graphify/build.lock')

Write-Host "`nProvenance breakdown"

$mixed = Invoke-Target -Arguments @('status') -WorkingDirectory (Join-Path $Fixtures 'graph-build-mixed')
foreach ($label in @('EXTRACTED', 'INFERRED', 'AMBIGUOUS')) {
    $count = Get-Field $mixed.Out "evidence_$label"
    if ($count -and [int] $count -gt 0) {
        Pass "mixed fixture reports $label verbatim"
    } else {
        Fail "mixed fixture reports $label" "got $(if ($count) { $count } else { '<none>' })"
    }
}

Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue

Write-Host "`n$($script:Passed) passed, $($script:Failed) failed"
if ($script:Failed -gt 0) { exit 1 }
