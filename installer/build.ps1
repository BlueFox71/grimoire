# Fabrique dist\Grimoire-Setup-<version>.exe : l'installateur de la version Windows, celui que Le Grenier télécharge.
# Usage : powershell -ExecutionPolicy Bypass -File installer\build.ps1 [-SansFlutter]
#   -SansFlutter : réutilise le build Flutter déjà présent (app\build\windows\x64\runner\Release)
param([switch]$SansFlutter)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root 'dist'
$version = (Select-String -Path (Join-Path $root 'app\pubspec.yaml') -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
Write-Host "Grimoire $version"

if (-not $SansFlutter) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\build-windows.ps1')
  if ($LASTEXITCODE) { throw 'la fabrication de la version Windows a échoué.' }
}
$release = Join-Path $root 'app\build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'Grimoire.exe'))) { throw "$release\Grimoire.exe introuvable : lancez sans -SansFlutter." }

Write-Host 'Compression…'
New-Item -ItemType Directory -Force $dist | Out-Null
$staging = Join-Path $dist 'contenu'
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
Copy-Item $release $staging -Recurse
[IO.File]::WriteAllText((Join-Path $staging 'version.txt'), $version, (New-Object Text.UTF8Encoding $false))
$zip = Join-Path $dist 'contenu.zip'
if (Test-Path $zip) { Remove-Item $zip }
[IO.Compression.ZipFile]::CreateFromDirectory($staging, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
Remove-Item $staging -Recurse -Force

Write-Host 'Compilation de l''installateur…'
$csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
$stub = Join-Path $dist 'setup-stub.exe'
& $csc /nologo /codepage:65001 /target:winexe /optimize+ /platform:anycpu "/out:$stub" `
  "/win32icon:$(Join-Path $root 'app\windows\runner\resources\app_icon.ico')" `
  /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll `
  (Join-Path $PSScriptRoot 'Setup.cs')
if ($LASTEXITCODE) { throw 'compilation impossible' }

Write-Host 'Assemblage…'
$exe = Join-Path $dist "Grimoire-Setup-$version.exe"
$out = [IO.File]::Create($exe)
foreach ($part in $stub, $zip) { $in = [IO.File]::OpenRead($part); $in.CopyTo($out, 1MB); $in.Close() }
$out.Write([BitConverter]::GetBytes([long](Get-Item $stub).Length), 0, 8)
$out.Write([Text.Encoding]::ASCII.GetBytes('GRIMOIR1'), 0, 8)
$out.Close()
Remove-Item $zip, $stub
Write-Host ("Installateur prêt : {0} ({1:N0} Mo)" -f $exe, ((Get-Item $exe).Length / 1MB))
