param([switch]$Update)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repoRoot = Split-Path $PSScriptRoot -Parent
$toolsRoot = Join-Path $repoRoot '.local-tools'
New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null

function Get-VerifiedFile([string]$Url, [string]$ChecksumUrl, [string]$Destination, [string]$ChecksumName) {
    $temporary = "$Destination.download"
    & curl.exe --fail --location --retry 2 --connect-timeout 20 --max-time 600 --silent --show-error --output $temporary $Url
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
    $checksums = if ($ChecksumUrl.StartsWith('sha256:')) { $ChecksumUrl.Substring(7) } else { (Invoke-WebRequest -Uri $ChecksumUrl -UseBasicParsing -TimeoutSec 60).Content }
    if ($checksums -is [byte[]]) { $checksums = [Text.Encoding]::UTF8.GetString($checksums) }
    $line = $checksums -split "`n" | Where-Object { $_ -match [regex]::Escape($ChecksumName) } | Select-Object -First 1
    if (-not $line) { $line = $checksums.Trim() }
    $expected = [regex]::Match($line, '[a-fA-F0-9]{64}').Value
    if (-not $expected -or (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $expected) {
        throw "Checksum verification failed for $ChecksumName. The downloaded file was not installed."
    }
    Move-Item -LiteralPath $temporary -Destination $Destination -Force
}

$ytDlp = Join-Path $toolsRoot 'yt-dlp.exe'
if ($Update -or -not (Test-Path -LiteralPath $ytDlp)) {
    Write-Host 'Downloading yt-dlp from its official release...'
    # Resolve a single release to keep the executable and checksum consistent.
    $release = Invoke-RestMethod 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest'
    $binary = $release.assets | Where-Object name -eq 'yt-dlp.exe' | Select-Object -First 1
    $hashes = $release.assets | Where-Object name -eq 'SHA2-256SUMS' | Select-Object -First 1
    Get-VerifiedFile $binary.browser_download_url $hashes.browser_download_url $ytDlp 'yt-dlp.exe'
}

$ffmpeg = Join-Path $toolsRoot 'ffmpeg'
if ($Update -or -not (Test-Path -LiteralPath (Join-Path $ffmpeg 'ffmpeg.exe'))) {
    Write-Host 'Downloading the FFmpeg essentials build from Gyan official GitHub releases...'
    $archive = Join-Path $toolsRoot 'ffmpeg.zip'
    $release = Invoke-RestMethod 'https://api.github.com/repos/GyanD/codexffmpeg/releases/latest'
    $binary = $release.assets | Where-Object name -Like '*-essentials_build.zip' | Select-Object -First 1
    if (-not $binary -or -not $binary.digest) { throw 'No verified FFmpeg essentials release was found.' }
    Get-VerifiedFile $binary.browser_download_url $binary.digest $archive $binary.name
    $extract = Join-Path $toolsRoot ('ffmpeg-extract-' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $archive -DestinationPath $extract
    $bin = Get-ChildItem -LiteralPath $extract -Directory | ForEach-Object { Join-Path $_.FullName 'bin' } | Select-Object -First 1
    New-Item -ItemType Directory -Path $ffmpeg -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $bin 'ffmpeg.exe') -Destination $ffmpeg -Force
    Copy-Item -LiteralPath (Join-Path $bin 'ffprobe.exe') -Destination $ffmpeg -Force
    # Keep downloaded license/readme files alongside the portable tools.
    Get-ChildItem -LiteralPath $extract -Recurse -File | Where-Object { $_.Name -match 'LICENSE|COPYING|README' } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $ffmpeg -Force
    }
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Install Node.js 22 or later, then run the launcher again.' }
$nodeVersion = & node --version
if ([int]($nodeVersion.TrimStart('v').Split('.')[0]) -lt 22) { throw 'The downloader requires Node.js 22 or later.' }
& $ytDlp --version
if ($LASTEXITCODE -ne 0) { throw 'yt-dlp failed to start.' }
& (Join-Path $ffmpeg 'ffmpeg.exe') -version | Select-Object -First 1
Write-Host "Downloader tools are ready in $toolsRoot"
