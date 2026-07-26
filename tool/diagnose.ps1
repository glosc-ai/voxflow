[CmdletBinding()]
param(
    [ValidateSet('fast', 'network', 'doctor', 'windows', 'android', 'all')]
    [string]$Mode = 'fast'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-NativeStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    Write-Host "[diagnose] $Name"
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

function Invoke-FastLoop {
    Invoke-NativeStep `
        -Name 'Check Dart formatting' `
        -FilePath 'dart' `
        -Arguments @('format', '--output=none', '--set-exit-if-changed', '.')
    Invoke-NativeStep -Name 'Run static analysis' -FilePath 'flutter' -Arguments @('analyze')
    Invoke-NativeStep -Name 'Run automated tests' -FilePath 'flutter' -Arguments @('test')
}

function Invoke-DoctorCheck {
    Write-Host '[diagnose] Check Flutter toolchains and network resources'
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $doctorOutput = @(& flutter doctor -v 2>&1)
        $doctorExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $doctorOutput | ForEach-Object { Write-Host $_ }
    $doctorText = $doctorOutput | Out-String

    if ($doctorExitCode -ne 0) {
        throw "Flutter doctor failed with exit code $doctorExitCode."
    }
    if ($doctorText -match '(?m)^\[(?:!|X)\]') {
        throw 'Flutter doctor reported one or more unhealthy categories.'
    }
}

function Invoke-NetworkProbe {
    Invoke-NativeStep `
        -Name 'Probe GitHub through the Dart TLS stack' `
        -FilePath 'dart' `
        -Arguments @('tool/github_network_probe.dart', '10')
}

function Invoke-WindowsBuild {
    Invoke-NativeStep `
        -Name 'Build Windows release' `
        -FilePath 'flutter' `
        -Arguments @('build', 'windows')
}

function Invoke-AndroidBuild {
    Invoke-NativeStep `
        -Name 'Build split Android release APKs' `
        -FilePath 'flutter' `
        -Arguments @('build', 'apk', '--split-per-abi')
}

Push-Location $repoRoot
try {
    switch ($Mode) {
        'fast' {
            Invoke-FastLoop
        }
        'network' {
            Invoke-NetworkProbe
        }
        'doctor' {
            Invoke-DoctorCheck
        }
        'windows' {
            Invoke-WindowsBuild
        }
        'android' {
            Invoke-AndroidBuild
        }
        'all' {
            Invoke-NetworkProbe
            Invoke-DoctorCheck
            Invoke-FastLoop
            Invoke-WindowsBuild
            Invoke-AndroidBuild
        }
    }

    Write-Host "[diagnose] Mode '$Mode' passed."
}
finally {
    Pop-Location
}
