param(
    [string]$FlutterCommand = "flutter",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseSource = [System.IO.Path]::GetFullPath(
    (Join-Path $repoRoot "build\windows\x64\runner\Release")
)
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "dist"))
$packageRunId = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
$packageRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $distRoot "voxflow-windows-x64-$packageRunId")
)
$zipPath = [System.IO.Path]::GetFullPath(
    (Join-Path $distRoot "voxflow-windows-x64.zip")
)
$checksumPath = "$zipPath.sha256"
$sandboxConfigPath = [System.IO.Path]::GetFullPath(
    (Join-Path $distRoot "voxflow-windows-smoke.wsb")
)

function Assert-PathInside([string]$Path, [string]$Parent) {
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $resolvedParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd("\") + "\"
    if (-not $resolvedPath.StartsWith($resolvedParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the expected package directory: $resolvedPath"
    }
}

function Get-MsvcRuntimeDirectory {
    $vsWhere = Join-Path ${env:ProgramFiles(x86)} `
        "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vsWhere -PathType Leaf)) {
        throw "vswhere.exe was not found; cannot bundle the Visual C++ runtime."
    }

    $installationPath = (& $vsWhere -latest -products * `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -property installationPath | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($installationPath)) {
        throw "A Visual Studio installation with the C++ toolchain was not found."
    }

    $redistRoot = Join-Path $installationPath "VC\Redist\MSVC"
    $requiredRuntimeFiles = @(
        "msvcp140.dll",
        "vcruntime140.dll",
        "vcruntime140_1.dll"
    )
    foreach ($candidate in (Get-ChildItem -LiteralPath $redistRoot -Directory |
            Sort-Object Name -Descending)) {
        $runtimeDirectory = Join-Path $candidate.FullName "x64\Microsoft.VC143.CRT"
        $isComplete = $true
        foreach ($fileName in $requiredRuntimeFiles) {
            if (-not (Test-Path -LiteralPath (Join-Path $runtimeDirectory $fileName) -PathType Leaf)) {
                $isComplete = $false
                break
            }
        }
        if ($isComplete) {
            return $runtimeDirectory
        }
    }

    throw "A complete x64 Visual C++ runtime directory was not found."
}

if (-not $SkipBuild) {
    & $FlutterCommand build windows
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows Release build failed."
    }
}

$requiredSourcePaths = @(
    "voxflow.exe",
    "flutter_windows.dll",
    "data"
)
foreach ($relativePath in $requiredSourcePaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $releaseSource $relativePath))) {
        throw "Windows Release output is incomplete: $relativePath"
    }
}
$msvcRuntimeDirectory = Get-MsvcRuntimeDirectory

New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
Assert-PathInside $packageRoot $distRoot
Assert-PathInside $zipPath $distRoot
Assert-PathInside $checksumPath $distRoot
Assert-PathInside $sandboxConfigPath $distRoot

if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
foreach ($file in @($zipPath, $checksumPath, $sandboxConfigPath)) {
    if (Test-Path -LiteralPath $file) {
        Remove-Item -LiteralPath $file -Force
    }
}

New-Item -ItemType Directory -Path $packageRoot | Out-Null
Get-ChildItem -LiteralPath $releaseSource -Force |
    Copy-Item -Destination $packageRoot -Recurse -Force
Get-ChildItem -LiteralPath $msvcRuntimeDirectory -Filter "*.dll" -File |
    Copy-Item -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "docs\release\windows-limited-test.md") `
    -Destination (Join-Path $packageRoot "README.md") -Force

Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipPath -CompressionLevel Optimal
$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$zipHash  $([System.IO.Path]::GetFileName($zipPath))" -Encoding ASCII

$escapedHostFolder = [System.Security.SecurityElement]::Escape($packageRoot)
$sandboxConfig = @"
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$escapedHostFolder</HostFolder>
      <SandboxFolder>C:\VoxFlow</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <Networking>Enable</Networking>
  <AudioInput>Enable</AudioInput>
  <ClipboardRedirection>Disable</ClipboardRedirection>
  <LogonCommand>
    <Command>C:\VoxFlow\voxflow.exe</Command>
  </LogonCommand>
</Configuration>
"@
Set-Content -LiteralPath $sandboxConfigPath -Value $sandboxConfig -Encoding UTF8

Write-Output "WINDOWS_PACKAGE=$zipPath"
Write-Output "WINDOWS_PACKAGE_ROOT=$packageRoot"
Write-Output "WINDOWS_PACKAGE_SHA256=$zipHash"
Write-Output "WINDOWS_SANDBOX_CONFIG=$sandboxConfigPath"
