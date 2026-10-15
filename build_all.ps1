$ErrorActionPreference = 'Stop'

function Get-FlutterExecutable {
    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidatePaths = @(
        "$env:LOCALAPPDATA\Pub\Cache\bin",
        "$env:ProgramFiles\Flutter\bin",
        "$env:ProgramFiles(x86)\Flutter\bin",
        "$env:USERPROFILE\sdk\flutter\bin",
        "D:\src\flutter\bin",
        "D:\flutter\bin",
        "C:\src\flutter\bin",
        "C:\flutter\bin"
    )

    foreach ($candidate in $candidatePaths) {
        $flutterExe = Join-Path $candidate 'flutter.bat'
        if (Test-Path $flutterExe) {
            return $flutterExe
        }
    }

    return $null
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$androidDir = Join-Path $root 'android_agent'
$desktopDir = Join-Path $root 'desktop_controller'

$flutterCmd = Get-FlutterExecutable
if (-not $flutterCmd) {
    Write-Error 'Flutter SDK was not found in PATH or in common Windows install locations. Install Flutter and ensure `flutter` is available in PATH before running this script.'
    exit 1
}

Write-Host "Using Flutter: $flutterCmd"

Push-Location $androidDir
try {
    Write-Host '==> Building Android APK (release)'
    & $flutterCmd pub get
    & $flutterCmd clean
    & $flutterCmd build apk --release --dart-define-from-file=config/server.json
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
}
finally {
    Pop-Location
}

Push-Location $desktopDir
try {
    Write-Host '==> Enabling Windows desktop support'
    & $flutterCmd config --enable-windows-desktop

    Write-Host '==> Building Windows EXE (release)'
    & $flutterCmd pub get
    & $flutterCmd clean
    & $flutterCmd build windows --release --dart-define-from-file=config/server.json
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
}
finally {
    Pop-Location
}

Write-Host '==> Build complete'
Write-Host "APK: $androidDir\build\app\outputs\flutter-apk\app-release.apk"
Write-Host "EXE: $desktopDir\build\windows\x64\runner\Release\quicksupport_desktop_controller.exe"
