param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,
    [switch]$Launch
)

$ErrorActionPreference = "Stop"
$resolvedZip = [System.IO.Path]::GetFullPath($ZipPath)
if (-not (Test-Path -LiteralPath $resolvedZip -PathType Leaf)) {
    throw "Windows package does not exist: $resolvedZip"
}

$checksumPath = "$resolvedZip.sha256"
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "Windows package checksum does not exist: $checksumPath"
}
$checksumLine = (Get-Content -LiteralPath $checksumPath -Raw).Trim()
if ($checksumLine -notmatch '^([0-9a-fA-F]{64})\s+') {
    throw "Windows package checksum file is invalid."
}
$expectedHash = $Matches[1].ToLowerInvariant()
$actualHash = (Get-FileHash -LiteralPath $resolvedZip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "Windows package checksum verification failed."
}

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $tempBase ("voxflow-package-" + [Guid]::NewGuid().ToString("N")))
)
if (-not $tempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Package temp path is outside the system temp directory."
}

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Expand-Archive -LiteralPath $resolvedZip -DestinationPath $tempRoot

    $requiredPaths = @(
        "voxflow.exe",
        "flutter_windows.dll",
        "msvcp140.dll",
        "vcruntime140.dll",
        "vcruntime140_1.dll",
        "data\flutter_assets",
        "README.md"
    )
    foreach ($relativePath in $requiredPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $tempRoot $relativePath))) {
            throw "Packaged Windows runtime is incomplete: $relativePath"
        }
    }
    $forbiddenFiles = Get-ChildItem -LiteralPath $tempRoot -Recurse -File |
        Where-Object { $_.Extension -in @(".dart", ".jks", ".keystore") }
    if ($forbiddenFiles) {
        throw "Package contains source or signing material."
    }

    if ($Launch) {
        $process = Start-Process -FilePath (Join-Path $tempRoot "voxflow.exe") `
            -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 5
        if ($process.HasExited) {
            throw "Packaged VoxFlow process exited during startup."
        }
        Stop-Process -Id $process.Id
        $process.WaitForExit()
    }

    Write-Output "Windows package verification passed."
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        if ($resolvedTempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
        }
    }
}
