param(
    [string]$FlutterCommand = "flutter",
    [switch]$SplitPerAbi
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $tempBase ("voxflow-signing-" + [Guid]::NewGuid().ToString("N")))
)

if (-not $tempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Signing temp path is outside the system temp directory."
}

$signingVariables = @(
    "VOXFLOW_ANDROID_KEYSTORE_PATH",
    "VOXFLOW_ANDROID_KEYSTORE_PASSWORD",
    "VOXFLOW_ANDROID_KEY_ALIAS",
    "VOXFLOW_ANDROID_KEY_PASSWORD"
)
$originalValues = @{}
foreach ($name in $signingVariables) {
    $originalValues[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

function Set-ProcessVariable([string]$Name, [string]$Value) {
    [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
}

function Invoke-FlutterReleaseBuild {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $buildArguments = @("build", "apk", "--release")
        if ($SplitPerAbi) {
            $buildArguments += "--split-per-abi"
        }
        else {
            $buildArguments += @("--target-platform", "android-arm64")
        }
        $output = & $FlutterCommand @buildArguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    return @{
        ExitCode = $exitCode
        Output = ($output -join [Environment]::NewLine)
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null

    foreach ($name in $signingVariables) {
        Set-ProcessVariable $name $null
    }
    $unsignedBuild = Invoke-FlutterReleaseBuild
    if ($unsignedBuild.ExitCode -eq 0) {
        throw "Release build succeeded without signing inputs."
    }
    if ($unsignedBuild.Output -notmatch "VOXFLOW_ANDROID_KEYSTORE_PATH") {
        throw "Release build failed without the expected signing guidance."
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $javaSettings = & java -XshowSettings:properties -version 2>&1
        $javaExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($javaExitCode -ne 0) {
        throw "Unable to query Java properties."
    }
    $javaHomeLine = $javaSettings | Where-Object { $_ -match "^\s*java\.home\s*=" } | Select-Object -First 1
    if ($null -eq $javaHomeLine) {
        throw "Unable to resolve Java Home."
    }
    $javaHome = ($javaHomeLine -split "=", 2)[1].Trim()
    $keytool = Join-Path $javaHome "bin\keytool.exe"
    if (-not (Test-Path -LiteralPath $keytool)) {
        throw "The current JDK does not include keytool."
    }

    $sdkRoot = $env:ANDROID_SDK_ROOT
    if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
        $sdkRoot = $env:ANDROID_HOME
    }
    if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
        $localProperties = Get-Content -LiteralPath (Join-Path $repoRoot "android\local.properties") -Encoding UTF8
        $sdkLine = $localProperties | Where-Object { $_ -like "sdk.dir=*" } | Select-Object -First 1
        if ($null -ne $sdkLine) {
            $sdkRoot = ($sdkLine -split "=", 2)[1].Replace("\\", "\")
        }
    }
    if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
        throw "Unable to resolve the Android SDK path."
    }
    $buildTools = Get-ChildItem -LiteralPath (Join-Path $sdkRoot "build-tools") -Directory |
        Sort-Object { [Version]$_.Name } -Descending |
        Select-Object -First 1
    $apksigner = Join-Path $buildTools.FullName "apksigner.bat"
    if (-not (Test-Path -LiteralPath $apksigner)) {
        throw "The Android SDK does not include apksigner."
    }

    $keystore = Join-Path $tempRoot "voxflow-test.jks"
    $testPassword = "voxflow-signing-test"
    & $keytool -genkeypair -keystore $keystore -storepass $testPassword `
        -keypass $testPassword -alias "voxflow-test" -keyalg RSA -keysize 2048 `
        -validity 1 -dname "CN=VoxFlow Signing Verification, O=glosc-ai, C=CN" -noprompt | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to generate the ephemeral test keystore."
    }

    Set-ProcessVariable "VOXFLOW_ANDROID_KEYSTORE_PATH" $keystore
    Set-ProcessVariable "VOXFLOW_ANDROID_KEYSTORE_PASSWORD" $testPassword
    Set-ProcessVariable "VOXFLOW_ANDROID_KEY_ALIAS" "voxflow-test"
    Set-ProcessVariable "VOXFLOW_ANDROID_KEY_PASSWORD" $testPassword

    $signedBuild = Invoke-FlutterReleaseBuild
    if ($signedBuild.ExitCode -ne 0) {
        throw "Release build failed with complete signing inputs.`n$($signedBuild.Output)"
    }

    $apkDirectory = Join-Path $repoRoot "build\app\outputs\flutter-apk"
    $apkNames = if ($SplitPerAbi) {
        @(
            "app-armeabi-v7a-release.apk",
            "app-arm64-v8a-release.apk",
            "app-x86_64-release.apk"
        )
    }
    else {
        @("app-release.apk")
    }
    foreach ($apkName in $apkNames) {
        $apk = Join-Path $apkDirectory $apkName
        if (-not (Test-Path -LiteralPath $apk)) {
            throw "Expected Release APK was not generated: $apkName"
        }
        $verification = & $apksigner verify --print-certs $apk 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Release APK signature verification failed: $apkName"
        }
        if (($verification -join "`n") -notmatch "VoxFlow Signing Verification") {
            throw "Release APK used an unexpected certificate: $apkName"
        }
    }

    Write-Output "Android Release signing verification passed for $($apkNames.Count) APK(s)."
}
finally {
    foreach ($name in $signingVariables) {
        Set-ProcessVariable $name $originalValues[$name]
    }
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        if ($resolvedTempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
        }
    }
}
