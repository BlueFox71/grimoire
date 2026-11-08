# Fabrique l'APK à installer sur le téléphone : dist\Grimoire-<version>.apk
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'
$env:Path = "C:\dev\flutter\bin;" + $env:Path

$keys = 'C:\Users\PC-Jules\Grimoire-cles\key.properties'
if (-not (Test-Path $keys)) { throw "Clé de signature introuvable : $keys" }
Copy-Item $keys "$app\android\key.properties" -Force

$version = (Select-String -Path "$app\pubspec.yaml" -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
Push-Location $app
try {
    $ErrorActionPreference = 'Continue'  # Flutter écrit sa progression sur stderr
    flutter build apk --release --split-per-abi --no-tree-shake-icons  # l'optimisation des icônes en retire qui sont utilisées (Flutter 3.47)
    if ($LASTEXITCODE -ne 0) { throw "La fabrication de l'APK a échoué." }
} finally { Pop-Location }

New-Item -ItemType Directory -Force "$root\dist" | Out-Null
$out = "$root\dist\Grimoire-$version.apk"
Copy-Item "$app\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" $out -Force
Write-Host "APK prêt : $out ($([math]::Round((Get-Item $out).Length / 1MB, 1)) Mo)"
