# Fabrique la version Windows : dist\Grimoire-Windows-<version>.zip
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'
$env:Path = "C:\dev\flutter\bin;" + $env:Path

$version = (Select-String -Path "$app\pubspec.yaml" -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
Push-Location $app
try {
    $ErrorActionPreference = 'Continue'  # Flutter écrit sa progression sur stderr
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "La fabrication de la version Windows a échoué." }
} finally { Pop-Location }

$release = "$app\build\windows\x64\runner\Release"
Move-Item "$release\grimoire.exe" "$release\Grimoire.exe" -Force
New-Item -ItemType Directory -Force "$root\dist" | Out-Null
$out = "$root\dist\Grimoire-Windows-$version.zip"
if (Test-Path $out) { Remove-Item $out }
Compress-Archive -Path "$release\*" -DestinationPath $out
Write-Host "Version Windows prête : $out ($([math]::Round((Get-Item $out).Length / 1MB, 1)) Mo)"
