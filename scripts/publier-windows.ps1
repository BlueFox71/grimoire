# Publie la version Windows de Grimoire sur GitHub : c'est cette release que Le Grenier installe et met à jour.
# Elle contient l'installateur (installer\build.ps1) et l'APK Android (bouton « Obtenir l'application mobile » du Grenier), avec
# RELEASE_NOTES.md comme notes (section « Actualités » de la fiche).
#   powershell -ExecutionPolicy Bypass -File scripts\publier-windows.ps1           publication réelle
#   powershell -ExecutionPolicy Bypass -File scripts\publier-windows.ps1 -DryRun   vérifications seules
# Nécessite la CLI GitHub (gh) connectée avec un accès en écriture au dépôt.
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$repo = 'BlueFox71/grimoire'
Set-Location $root

function Stop-Publication($message) { Write-Host "ERREUR : $message" -ForegroundColor Red; exit 1 }
function Etape($texte) { Write-Host "==> $texte" -ForegroundColor Cyan }

$version = (Select-String -Path (Join-Path $root 'app\pubspec.yaml') -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
$tag = "v$version"
Write-Host "Grimoire $version (tag $tag)"
if ($DryRun) { Write-Host 'SIMULATION : rien ne sera construit, tagué ni publié.' -ForegroundColor Yellow }

Etape 'Accès au dépôt GitHub'
$ErrorActionPreference = 'Continue'
$visibility = (& gh repo view $repo --json visibility --jq .visibility 2>$null)
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($code) { Stop-Publication "gh ne voit pas $repo : ajoute ce dépôt à ton jeton GitHub (Contents : lecture et écriture), ou reconnecte gh (gh auth login)." }
Write-Host "Dépôt $repo ($visibility)"

Etape 'Branche et arbre de travail'
$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'main') { Stop-Publication "la publication se fait depuis main (branche actuelle : $branch)." }
if (& git status --porcelain) { Stop-Publication "l'arbre de travail n'est pas propre : commite ou range tes modifications." }
$ErrorActionPreference = 'Continue'  # git écrit sur stderr même quand tout va bien
& git fetch -q origin main 2>$null
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($code) { Stop-Publication "impossible de joindre GitHub (git fetch)." }
$head = (& git rev-parse HEAD).Trim()
if ($head -ne (& git rev-parse origin/main).Trim()) { Stop-Publication "main n'est pas identique à origin/main : pousse ou tire d'abord." }

Etape 'Notes de version'
$notesFile = Join-Path $root 'RELEASE_NOTES.md'
if (-not (Test-Path $notesFile)) { Stop-Publication 'RELEASE_NOTES.md est introuvable.' }
$notes = Get-Content $notesFile -Raw -Encoding UTF8
if ($notes -notmatch '^\s*<!--\s*version:\s*([^\s>]+)\s*-->') { Stop-Publication 'RELEASE_NOTES.md doit commencer par <!-- version: X.Y.Z -->.' }
if ($Matches[1] -ne $version) { Stop-Publication "RELEASE_NOTES.md est celui de la version $($Matches[1]), pas de $version : rédige le rapport de cette version." }
$notes = ($notes -replace '^\s*<!--[^>]*-->\s*', '').Trim()
if (-not $notes) { Stop-Publication 'RELEASE_NOTES.md est vide.' }

Etape 'Tag'
if (& git tag --list $tag) { Stop-Publication "le tag $tag existe déjà." }
if (& git ls-remote --tags origin "refs/tags/$tag") { Stop-Publication "le tag $tag existe déjà sur GitHub." }

Etape 'APK'
$apk = Join-Path $root "dist\Grimoire-$version.apk"
if (-not (Test-Path $apk)) { Stop-Publication "$apk est introuvable : fabrique d'abord l'APK (scripts\build-android.ps1)." }
Write-Host $apk

if ($DryRun) { Write-Host 'Simulation terminée : tout est prêt pour la publication.' -ForegroundColor Green; exit 0 }

Etape 'Installateur Windows'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'installer\build.ps1')
if ($LASTEXITCODE) { Stop-Publication "la construction de l'installateur a échoué." }
$exe = Join-Path $root "dist\Grimoire-Setup-$version.exe"
if (-not (Test-Path $exe)) { Stop-Publication "$exe est introuvable." }

Etape 'Release GitHub'
# gh crée le tag sur le commit publié en même temps que la release : pas d'état intermédiaire « tag poussé sans
# release » qui bloquerait une nouvelle tentative.
$notesTemp = Join-Path $env:TEMP "grimoire-notes-$version.md"
[IO.File]::WriteAllText($notesTemp, $notes, (New-Object Text.UTF8Encoding $false))
$ErrorActionPreference = 'Continue'  # gh écrit sa progression sur stderr
& gh release create $tag $exe $apk --repo $repo --target $head --title $version --notes-file $notesTemp
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Remove-Item $notesTemp
if ($code) { Stop-Publication "la release n'a pas pu être créée. Vérifie sur GitHub qu'aucune release $tag incomplète n'est restée, puis relance." }
& git fetch -q origin "refs/tags/${tag}:refs/tags/$tag" 2>$null
Write-Host "Grimoire $version est publié : Le Grenier le proposera au prochain démarrage." -ForegroundColor Green
