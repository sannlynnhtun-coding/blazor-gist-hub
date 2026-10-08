param([switch]$NoBrowser, [switch]$NoBuild)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$baseUrl = 'http://localhost:5188'
try {
    $existing = Invoke-RestMethod "$baseUrl/api/downloader/health" -TimeoutSec 5
    if ($null -ne $existing.ready) {
        if (-not $NoBrowser) { Start-Process "$baseUrl/tools/youtube-downloader" }
        Write-Host "GistHub local downloader is already running at $baseUrl"
        return
    }
} catch { }

& (Join-Path $PSScriptRoot 'install-downloader-tools.ps1')
$clientOutput = Join-Path $repoRoot 'artifacts/local-downloader/client'
$hostOutput = Join-Path $repoRoot 'artifacts/local-downloader/host'
if (-not $NoBuild) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'GistHub/node_modules'))) {
        & npm install --prefix (Join-Path $repoRoot 'GistHub')
        if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }
    }
    & dotnet publish (Join-Path $repoRoot 'GistHub/GistHub.csproj') -c Release -o $clientOutput --nologo
    if ($LASTEXITCODE -ne 0) { throw 'GistHub publish failed.' }
    & dotnet publish (Join-Path $repoRoot 'GistHub.LocalDownloader/GistHub.LocalDownloader.csproj') -c Release -o $hostOutput --nologo
    if ($LASTEXITCODE -ne 0) { throw 'Downloader publish failed.' }
}
$hostDll = Join-Path $hostOutput 'GistHub.LocalDownloader.dll'
$webRoot = Join-Path $clientOutput 'wwwroot'
if (-not (Test-Path -LiteralPath $hostDll) -or -not (Test-Path -LiteralPath $webRoot)) { throw 'Run the launcher without -NoBuild first.' }
$toolsRoot = Join-Path $repoRoot '.local-tools'
$hostArguments = @($hostDll, '--webroot', $webRoot,
    '--environment', 'Development', '--Downloader:ParentProcessId', "$PID",
    '--Downloader:YtDlp', (Join-Path $toolsRoot 'yt-dlp.exe'),
    '--Downloader:Ffmpeg', (Join-Path $toolsRoot 'ffmpeg/ffmpeg.exe'),
    '--Downloader:Ffprobe', (Join-Path $toolsRoot 'ffmpeg/ffprobe.exe'))

# Launch directly without a shell; quote each argument for Windows paths with spaces.
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = (Get-Command dotnet).Source
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.WorkingDirectory = $repoRoot
# Windows PowerShell 5.1 has no ProcessStartInfo.ArgumentList.
$startInfo.Arguments = ($hostArguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
$process = [Diagnostics.Process]::Start($startInfo)
try {
    $running = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        if ($process.HasExited) { throw 'The local service stopped. Check the output above (port 5188 may already be in use).' }
        try {
            $health = Invoke-RestMethod "$baseUrl/api/downloader/health" -TimeoutSec 3
            $running = $true
            break
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $running) { throw 'The local downloader did not start in time.' }
    Write-Host "GistHub is running at $baseUrl. Close this launcher or press Ctrl+C to stop."
    if (-not $NoBrowser) { Start-Process "$baseUrl/tools/youtube-downloader" }
    $process.WaitForExit()
} finally {
    # The service watches this launcher's process and shuts down gracefully when
    # it exits, cancelling media processes before stopping.
    $process.Dispose()
}
