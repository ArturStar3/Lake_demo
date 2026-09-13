# Import and start the offline single-container InfoLake demonstration.
param(
    [Parameter(Mandatory = $true)]
    [string]$Archive,
    [string]$EnvFile = ".env.demo"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$archivePath = Resolve-Path -LiteralPath $Archive -ErrorAction Stop
$envPath = Join-Path $PSScriptRoot $EnvFile
if (-not (Test-Path -LiteralPath $envPath)) {
    throw "'$EnvFile' is required. Copy .env.demo.example, set secrets and external MBTiles/media paths, then retry."
}

docker load -i $archivePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$networkName = ((Get-Content -LiteralPath $envPath) |
    Where-Object { $_ -match '^\s*DEMO_NETWORK\s*=' } |
    Select-Object -First 1) -replace '^\s*DEMO_NETWORK\s*=\s*', ''
if ([string]::IsNullOrWhiteSpace($networkName)) { $networkName = "infolake-integration" }

docker network inspect $networkName 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    docker network create $networkName | Out-Null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

docker compose -p infolake-demo --env-file $envPath config --quiet
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
docker compose -p infolake-demo --env-file $envPath up -d --no-build --pull never
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
docker compose -p infolake-demo --env-file $envPath ps
