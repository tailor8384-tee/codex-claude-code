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

$repoRoot = Get-RepoRoot
$envFile = Join-Path $repoRoot '.env'

if (-not (Test-Path -LiteralPath $envFile)) {
    Write-Error 'FIRECRAWL_API_KEY missing'
    exit 1
}

$keyLine = Get-Content -LiteralPath $envFile -Encoding UTF8 |
    Where-Object { $_ -match '^\s*FIRECRAWL_API_KEY\s*=' } |
    Select-Object -First 1

if (-not $keyLine) {
    Write-Error 'FIRECRAWL_API_KEY missing'
    exit 1
}

$parts = $keyLine -split '=', 2
if ($parts.Count -lt 2) {
    Write-Error 'FIRECRAWL_API_KEY missing'
    exit 1
}

$apiKey = $parts[1].Trim()
$apiKey = $apiKey.Trim('"').Trim("'")

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Error 'FIRECRAWL_API_KEY missing'
    exit 1
}

$env:FIRECRAWL_API_KEY = $apiKey
& npx -y firecrawl-mcp
