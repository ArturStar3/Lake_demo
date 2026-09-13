# Build and export the single-container InfoLake demonstration image.
param(
    [string]$OutputDir = ".",
    [string]$Image = "infolake-demo:latest",
    [switch]$NoCache,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not $SkipBuild) {
    $buildArgs = @("build", "--file", "Dockerfile.demo", "--tag", $Image)
    if ($NoCache) { $buildArgs += "--no-cache" }
    $buildArgs += "."
    docker @buildArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

docker image inspect $Image 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Image '$Image' is absent. Build it first or omit -SkipBuild."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$stableArchive = Join-Path $OutputDir "infolake_demo_offline.tar"
$datedArchive = Join-Path $OutputDir "infolake_demo_offline_$timestamp.tar"
$manifest = Join-Path $OutputDir "offline-package-manifest-demo.txt"

docker save -o $stableArchive $Image
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item -LiteralPath $stableArchive -Destination $datedArchive -Force

$imageId = (docker image inspect $Image --format '{{.Id}}').Trim()
$sizeMb = [math]::Round((Get-Item -LiteralPath $stableArchive).Length / 1MB, 1)
@"
InfoLake single-image demonstration package
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Image: $Image
Image ID: $imageId
Archive: $stableArchive
Size: $sizeMb MB

Copy separately (they are deliberately NOT inside the image):
  - .env.demo, based on .env.demo.example, with actual secrets and absolute paths;
  - map.mbtiles at the path named by MBTILES_PATH;
  - the media directory named by MEDIA_PATH;
  - docker-compose.yml and import-and-start-demo.ps1.

On the target host run:
  .\import-and-start-demo.ps1 -Archive <path-to-infolake_demo_offline.tar>

Do not use docker compose build, docker pull, or docker compose up --build on an offline host.
"@ | Set-Content -LiteralPath $manifest -Encoding utf8

Write-Host "Done: $stableArchive"
Write-Host "Manifest: $manifest"
