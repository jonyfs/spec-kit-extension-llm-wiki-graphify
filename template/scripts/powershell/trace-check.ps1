#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Traceability check for a single Spec Kit feature directory.

.DESCRIPTION
    Compares spec.md, plan.md and tasks.md against each other and reports the
    inconsistencies that are mechanically decidable:

      * a required artifact is missing
      * a user story in spec.md has no task tagged with it in tasks.md
      * a task is tagged with a user story that spec.md does not define
      * a task cites a requirement ID that spec.md does not define
      * a requirement ID is defined twice in spec.md
      * a task ID is used twice in tasks.md
      * an unresolved [NEEDS CLARIFICATION] marker survives in spec.md
      * (optional) a requirement in spec.md that no task cites

    The script only reads files. It never writes, never touches git state, and
    never looks outside the feature directory it was pointed at.

    Behaviorally equivalent to scripts/bash/trace-check.sh.

.PARAMETER Feature
    A feature directory path, or a feature name resolved under <repo>/specs/.

.PARAMETER Json
    Emit a single-line JSON object instead of the human-readable report.

.PARAMETER WarnOnly
    Report findings but always exit 0.

.NOTES
    Feature resolution order:
      1. -Feature <path>            an existing directory, used as-is
      2. -Feature <name>            resolved to <repo>/specs/<name>
      3. $env:SPECIFY_FEATURE       resolved to <repo>/specs/$env:SPECIFY_FEATURE
      4. current git branch name    resolved to <repo>/specs/<branch>
      5. the most recently modified <repo>/specs/*/spec.md

    Exit codes:
      0  no findings, or -WarnOnly / warn_only: true
      1  at least one finding
      2  no feature directory could be resolved
#>

[CmdletBinding()]
param(
    [string]$Feature = '',
    [switch]$Json,
    [switch]$WarnOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Repository root
# --------------------------------------------------------------------------

function Get-RepoRoot {
    try {
        $root = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $root) { return $root.Trim() }
    } catch {
        # git is absent or this is not a repository; fall through.
    }
    return (Get-Location).Path
}

$RepoRoot = Get-RepoRoot

# --------------------------------------------------------------------------
# Configuration
#
# Flat `key: value` pairs only. local-config.yml wins over trace-config.yml,
# and both are optional.
# --------------------------------------------------------------------------

$ConfigDir = Join-Path (Join-Path (Join-Path $RepoRoot '.specify') 'extensions') 'trace'

function Get-ConfigValue {
    param([string]$Key, [string]$Default)

    foreach ($name in @('local-config.yml', 'trace-config.yml')) {
        $path = Join-Path $ConfigDir $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }

        foreach ($line in (Get-Content -LiteralPath $path)) {
            if ($line -notmatch "^\s*$([regex]::Escape($Key))\s*:") { continue }

            $value = $line.Substring($line.IndexOf(':') + 1)
            $value = $value.Trim()
            $value = [regex]::Replace($value, '\s+#.*$', '')
            $value = $value.Trim()
            if ($value.Length -ge 2 -and
                (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                 ($value.StartsWith("'") -and $value.EndsWith("'")))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            if ($value) { return $value }
        }
    }
    return $Default
}

function Test-TruthyValue {
    param([string]$Value)
    return @('true', 'yes', 'on', '1') -contains $Value.ToLowerInvariant()
}

$RequirementPattern = Get-ConfigValue -Key 'requirement_pattern' -Default '(FR|NFR|SC)-[0-9]+'
$RequireCoverage = Test-TruthyValue (Get-ConfigValue -Key 'require_requirement_coverage' -Default 'false')
$FailOnClarification = Test-TruthyValue (Get-ConfigValue -Key 'fail_on_needs_clarification' -Default 'true')
$WarnOnlyEffective = Test-TruthyValue (Get-ConfigValue -Key 'warn_only' -Default 'false')
if ($WarnOnly) { $WarnOnlyEffective = $true }

# --------------------------------------------------------------------------
# Feature resolution
# --------------------------------------------------------------------------

function Resolve-FeatureDir {
    if ($Feature) {
        if (Test-Path -LiteralPath $Feature -PathType Container) {
            return (Resolve-Path -LiteralPath $Feature).Path
        }
        $candidate = Join-Path (Join-Path $RepoRoot 'specs') $Feature
        if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }
        return $null
    }

    if ($env:SPECIFY_FEATURE) {
        $candidate = Join-Path (Join-Path $RepoRoot 'specs') $env:SPECIFY_FEATURE
        if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }
    }

    try {
        $branch = & git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $branch) {
            $candidate = Join-Path (Join-Path $RepoRoot 'specs') $branch.Trim()
            if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }
        }
    } catch {
        # No git; fall through to the newest spec.md.
    }

    $specsDir = Join-Path $RepoRoot 'specs'
    if (Test-Path -LiteralPath $specsDir -PathType Container) {
        $newest = Get-ChildItem -LiteralPath $specsDir -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'spec.md' } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Get-Item |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($newest) { return $newest.Directory.FullName }
    }

    return $null
}

$FeatureDir = Resolve-FeatureDir
if (-not $FeatureDir) {
    Write-Error -Message ("trace-check: no feature directory found.`n" +
        "  Looked for: -Feature, `$env:SPECIFY_FEATURE, specs/<current-branch>, specs/*/spec.md`n" +
        "  Run /speckit.specify first, or pass -Feature <dir>.") -ErrorAction Continue
    exit 2
}

$SpecFile = Join-Path $FeatureDir 'spec.md'
$PlanFile = Join-Path $FeatureDir 'plan.md'
$TasksFile = Join-Path $FeatureDir 'tasks.md'
$FeatureName = Split-Path -Leaf $FeatureDir

# --------------------------------------------------------------------------
# Findings
# --------------------------------------------------------------------------

$Findings = [System.Collections.Generic.List[string]]::new()
$Notes = [System.Collections.Generic.List[string]]::new()

# --------------------------------------------------------------------------
# Check 1 - artifact presence
# --------------------------------------------------------------------------

$HasSpec = Test-Path -LiteralPath $SpecFile -PathType Leaf
$HasPlan = Test-Path -LiteralPath $PlanFile -PathType Leaf
$HasTasks = Test-Path -LiteralPath $TasksFile -PathType Leaf

$SpecLines = if ($HasSpec) { @(Get-Content -LiteralPath $SpecFile) } else { @() }
$TaskLines = if ($HasTasks) { @(Get-Content -LiteralPath $TasksFile) } else { @() }

if (-not $HasSpec) {
    $Findings.Add("spec.md is missing from $FeatureName; nothing can be traced without it")
}
if ($HasTasks -and -not $HasPlan) {
    $Findings.Add('tasks.md exists but plan.md does not; tasks were derived from nothing reviewable')
}
if (-not $HasTasks) { $Notes.Add('tasks.md not present yet; task-side checks were skipped') }
if (-not $HasPlan) { $Notes.Add('plan.md not present yet') }

# --------------------------------------------------------------------------
# Extraction helpers
# --------------------------------------------------------------------------

function Get-Matches {
    param([string[]]$Lines, [string]$Pattern, [string]$LinePattern = $null)

    $results = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $Lines) {
        if ($LinePattern -and $line -notmatch $LinePattern) { continue }
        foreach ($m in [regex]::Matches($line, $Pattern)) { $results.Add($m.Value) }
    }
    return $results
}

$taskLinePattern = '^\s*[-*]\s+\[[ xX]\]\s*T[0-9]+'
$reqDefLinePattern = "^\s*[-*]\s+\*\*(?:$RequirementPattern)\*\*"

$SpecStories = @()
$TaskStories = @()
if ($HasSpec) {
    $numbers = [System.Collections.Generic.List[int]]::new()
    foreach ($line in $SpecLines) {
        $m = [regex]::Match($line, '^#{2,4}\s+User Story\s+([0-9]+)')
        if ($m.Success) { $numbers.Add([int]$m.Groups[1].Value) }
    }
    $SpecStories = @($numbers | Sort-Object -Unique)
}
if ($HasTasks) {
    $TaskStories = @(Get-Matches -Lines $TaskLines -Pattern '\[US[0-9]+\]' |
        ForEach-Object { [int]($_ -replace '[^0-9]', '') } | Sort-Object -Unique)
}

# --------------------------------------------------------------------------
# Check 2 - user story coverage, both directions
# --------------------------------------------------------------------------

$StoryTotal = 0
$StoryCovered = 0

if ($HasSpec -and $HasTasks) {
    $StoryTotal = $SpecStories.Count
    foreach ($story in $SpecStories) {
        if ($TaskStories -contains $story) {
            $StoryCovered++
        } else {
            $Findings.Add("User Story $story is specified but no task in tasks.md is tagged [US$story]")
        }
    }
    foreach ($story in $TaskStories) {
        if ($SpecStories -notcontains $story) {
            $Findings.Add("tasks.md tags [US$story] but spec.md defines no User Story $story")
        }
    }
    if ($StoryTotal -eq 0) {
        $Notes.Add("spec.md declares no '### User Story N' headings; story coverage was not evaluated")
    }
}

# --------------------------------------------------------------------------
# Check 3 - requirement IDs
# --------------------------------------------------------------------------

$ReqTotal = 0
$ReqCited = 0

if ($HasSpec) {
    $specReqsAll = @(Get-Matches -Lines $SpecLines -Pattern $RequirementPattern -LinePattern $reqDefLinePattern)
    $specReqs = @($specReqsAll | Sort-Object -Unique)
    $ReqTotal = $specReqs.Count

    foreach ($group in ($specReqsAll | Group-Object)) {
        if ($group.Count -gt 1) {
            $Findings.Add("requirement $($group.Name) is defined more than once in spec.md")
        }
    }

    if ($HasTasks) {
        $taskReqs = @(Get-Matches -Lines $TaskLines -Pattern $RequirementPattern | Sort-Object -Unique)

        foreach ($req in $taskReqs) {
            if ($specReqs -notcontains $req) {
                $Findings.Add("tasks.md cites requirement $req, which spec.md does not define")
            }
        }
        foreach ($req in $specReqs) {
            if ($taskReqs -contains $req) {
                $ReqCited++
            } elseif ($RequireCoverage) {
                $Findings.Add("requirement $req is specified but no task cites it")
            }
        }
        if (-not $RequireCoverage -and $ReqTotal -gt 0) {
            $Notes.Add("requirement coverage is informational (require_requirement_coverage is false): $ReqCited/$ReqTotal cited by a task")
        }
    }
}

# --------------------------------------------------------------------------
# Check 4 - task IDs and progress
# --------------------------------------------------------------------------

$TaskTotal = 0
$TaskDone = 0

if ($HasTasks) {
    # The first T-identifier on a task line is the task's own id; later ones are
    # dependency references and must not be counted.
    $allTaskIds = @()
    foreach ($line in $TaskLines) {
        if ($line -match $taskLinePattern) {
            $allTaskIds += ([regex]::Match($line, 'T[0-9]+')).Value
        }
    }
    $TaskTotal = $allTaskIds.Count
    $TaskDone = @($TaskLines | Where-Object { $_ -match '^\s*[-*]\s+\[[xX]\]\s*T[0-9]+' }).Count

    foreach ($group in ($allTaskIds | Group-Object)) {
        if ($group.Count -gt 1) {
            $Findings.Add("task id $($group.Name) is used by more than one task in tasks.md")
        }
    }

    if ($TaskTotal -eq 0) {
        $Findings.Add("tasks.md contains no '- [ ] T###' task entries")
    }
}

# --------------------------------------------------------------------------
# Check 5 - unresolved clarifications
# --------------------------------------------------------------------------

$Clarifications = 0
if ($HasSpec) {
    $Clarifications = @($SpecLines | Where-Object { $_ -match 'NEEDS CLARIFICATION' }).Count
    if ($Clarifications -gt 0) {
        if ($FailOnClarification) {
            $Findings.Add("spec.md still has $Clarifications unresolved [NEEDS CLARIFICATION] marker(s); run /speckit.clarify")
        } else {
            $Notes.Add("spec.md has $Clarifications unresolved [NEEDS CLARIFICATION] marker(s)")
        }
    }
}

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------

if ($Json) {
    $payload = [ordered]@{
        feature       = $FeatureName
        feature_dir   = $FeatureDir
        artifacts     = [ordered]@{ spec = $HasSpec; plan = $HasPlan; tasks = $HasTasks }
        user_stories  = [ordered]@{ total = $StoryTotal; with_tasks = $StoryCovered }
        requirements  = [ordered]@{ total = $ReqTotal; cited_by_tasks = $ReqCited }
        tasks         = [ordered]@{ total = $TaskTotal; completed = $TaskDone }
        needs_clarification = $Clarifications
        findings      = @($Findings)
        notes         = @($Notes)
        finding_count = $Findings.Count
        warn_only     = $WarnOnlyEffective
    }
    Write-Output ($payload | ConvertTo-Json -Compress -Depth 5)
} else {
    Write-Output "Traceability check: $FeatureName"
    Write-Output "  directory   $FeatureDir"
    Write-Output ("  artifacts   spec.md={0} plan.md={1} tasks.md={2}" -f
        $HasSpec.ToString().ToLowerInvariant(),
        $HasPlan.ToString().ToLowerInvariant(),
        $HasTasks.ToString().ToLowerInvariant())
    Write-Output "  stories     $StoryCovered/$StoryTotal have at least one task"
    Write-Output "  requirements $ReqCited/$ReqTotal cited by a task"
    Write-Output "  tasks       $TaskDone/$TaskTotal complete"
    Write-Output "  clarify     $Clarifications unresolved marker(s)"

    if ($Notes.Count -gt 0) {
        Write-Output ''
        Write-Output 'Notes'
        foreach ($n in $Notes) { Write-Output "  - $n" }
    }

    Write-Output ''
    if ($Findings.Count -eq 0) {
        Write-Output 'No traceability findings.'
    } else {
        Write-Output "Findings ($($Findings.Count))"
        foreach ($f in $Findings) { Write-Output "  ! $f" }
    }
}

if ($Findings.Count -gt 0 -and -not $WarnOnlyEffective) { exit 1 }
exit 0
