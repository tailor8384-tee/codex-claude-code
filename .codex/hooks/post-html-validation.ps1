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

Write-HookLog -LogPath $logPath -Message '[HOOK] PostToolUse html validation started'

$statusLines = @(
    git -C $repoRoot diff --name-only --diff-filter=ACMRTUXB --cached
    git -C $repoRoot diff --name-only --diff-filter=ACMRTUXB
    git -C $repoRoot ls-files --others --exclude-standard
)

$changedIndexHtml = $statusLines | Where-Object { $_ -and $_ -match '(^|[\\/])index\.html$' } | Sort-Object -Unique

if (-not $changedIndexHtml) {
    Write-HookLog -LogPath $logPath -Message '[HOOK] PostToolUse html validation skipped'
    Write-Output (Write-Json @{ continue = $true })
    exit 0
}

foreach ($relativePath in $changedIndexHtml) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $reason = "index.html not found: $relativePath"
        Write-HookLog -LogPath $logPath -Message "[HOOK] PostToolUse html validation failed: $reason"
        Write-Output (Write-Json @{ decision = 'block'; reason = $reason })
        exit 0
    }

    $content = Get-Content -LiteralPath $fullPath -Raw
    $missing = @()
    foreach ($token in @('<html', '<head', '<body')) {
        if ($content -notmatch [regex]::Escape($token)) {
            $missing += $token
        }
    }

    if ($missing.Count -gt 0) {
        $reason = "HTML structure check failed for ${relativePath}: missing $($missing -join ', ')"
        Write-HookLog -LogPath $logPath -Message "[HOOK] PostToolUse html validation failed: $reason"
        Write-Output (Write-Json @{ decision = 'block'; reason = $reason })
        exit 0
    }
}

Write-HookLog -LogPath $logPath -Message '[HOOK] PostToolUse html validation passed'
Write-Output (Write-Json @{ continue = $true })
exit 0
