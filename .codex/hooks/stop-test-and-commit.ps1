$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-RepoRoot {
    Push-Location $PSScriptRoot
    try {
        (git rev-parse --show-toplevel).Trim()
    }
    finally {
        Pop-Location
    }
}

function Write-HookLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value "[$timestamp] $Message"
}

function Write-Json {
    param([Parameter(Mandatory = $true)]$Object)
    $Object | ConvertTo-Json -Compress -Depth 6
}

$repoRoot = Get-RepoRoot
$logPath = Join-Path $repoRoot '.codex\hooks\hook.log'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null
New-Item -ItemType File -Force -Path $logPath | Out-Null

Write-HookLog -LogPath $logPath -Message '[HOOK] Stop test and commit started'

$statusLines = @(
    git -C $repoRoot status --porcelain --untracked-files=normal
)

if (-not $statusLines) {
    Write-HookLog -LogPath $logPath -Message '[HOOK] Stop test and commit skipped: no changes'
    Write-Output (Write-Json @{ continue = $true })
    exit 0
}

$userName = git -C $repoRoot config --get user.name
$userEmail = git -C $repoRoot config --get user.email

if ($null -ne $userName) {
    $userName = $userName.Trim()
}
else {
    $userName = ''
}

if ($null -ne $userEmail) {
    $userEmail = $userEmail.Trim()
}
else {
    $userEmail = ''
}

if (-not $userName -or -not $userEmail) {
    $reason = 'git user.name or user.email is missing; auto commit blocked'
    Write-HookLog -LogPath $logPath -Message "[HOOK] Stop test and commit blocked: $reason"
    Write-Output (Write-Json @{ decision = 'block'; reason = $reason })
    exit 0
}

$changedFiles = @(
    git -C $repoRoot diff --name-only --diff-filter=ACMRTUXB --cached
    git -C $repoRoot diff --name-only --diff-filter=ACMRTUXB
    git -C $repoRoot ls-files --others --exclude-standard
    $statusLines | ForEach-Object {
        if ($_ -match '^\?\?\s+(?<path>.+)$') {
            $Matches.path
        }
        elseif ($_ -match '^[ MARCDAU?!]{2}\s+(?<path>.+)$') {
            $Matches.path
        }
    }
)

$changedFiles = $changedFiles | Where-Object { $_ } | Sort-Object -Unique

$validationFailures = New-Object System.Collections.Generic.List[string]
$pythonExe = $null

try {
    $pythonCommand = Get-Command python -ErrorAction Stop
    if ($pythonCommand.Source -and $pythonCommand.Source -notmatch 'WindowsApps') {
        $pythonExe = $pythonCommand.Source
    }
}
catch {
    $pythonExe = $null
}

if (-not $pythonExe) {
    $candidatePython = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python314\python.exe'
    if (Test-Path -LiteralPath $candidatePython) {
        $pythonExe = $candidatePython
    }
}

if (-not $pythonExe) {
    $validationFailures.Add('python executable not found for py_compile')
}

foreach ($relativePath in $changedFiles) {
    $fullPath = Join-Path $repoRoot $relativePath
    $extension = [System.IO.Path]::GetExtension($relativePath).ToLowerInvariant()

    switch ($extension) {
        '.html' {
            if (-not (Test-Path -LiteralPath $fullPath)) {
                $validationFailures.Add("missing file: $relativePath")
                continue
            }

            $content = Get-Content -LiteralPath $fullPath -Raw
            $missing = @()
            foreach ($token in @('<html', '<head', '<body')) {
                if ($content -notmatch [regex]::Escape($token)) {
                    $missing += $token
                }
            }

            if ($missing.Count -gt 0) {
                $validationFailures.Add("HTML structure check failed for ${relativePath}: missing $($missing -join ', ')")
            }
        }
        '.py' {
            if (-not (Test-Path -LiteralPath $fullPath)) {
                $validationFailures.Add("missing file: $relativePath")
                continue
            }

            & $pythonExe -m py_compile $fullPath
            if ($LASTEXITCODE -ne 0) {
                $validationFailures.Add("py_compile failed for $relativePath")
            }
        }
        default {
            continue
        }
    }
}

if ($validationFailures.Count -gt 0) {
    $reason = $validationFailures -join '; '
    Write-HookLog -LogPath $logPath -Message "[HOOK] Stop test and commit blocked: $reason"
    Write-Output (Write-Json @{ decision = 'block'; reason = $reason })
    exit 0
}

git -C $repoRoot add .
git -C $repoRoot commit -q -m 'auto: Codex generated update'

if ($LASTEXITCODE -ne 0) {
    $reason = 'git commit failed'
    Write-HookLog -LogPath $logPath -Message "[HOOK] Stop test and commit blocked: $reason"
    Write-Output (Write-Json @{ decision = 'block'; reason = $reason })
    exit 0
}

$commitHash = (git -C $repoRoot rev-parse HEAD).Trim()
Write-HookLog -LogPath $logPath -Message "[HOOK] Stop test and commit succeeded: $commitHash"
Write-Output (Write-Json @{ continue = $true })
exit 0
