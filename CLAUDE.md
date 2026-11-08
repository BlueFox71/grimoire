# Grimoire

## Rapport de version (Le Grenier)

La version Windows est distribuée par le Grenier, qui affiche les notes des releases GitHub dans la section
« Actualités » de la fiche. À chaque montée de version (`app/pubspec.yaml`), réécrire `RELEASE_NOTES.md` :

- première ligne : `<!-- version: X.Y.Z -->` (la version de `pubspec.yaml`, sans `+build`) ;
- en Markdown, pour l'utilisateur et non pour le développeur : ce qui change pour lui (`### Nouveautés`,
  `### Corrections`), pas les détails techniques ;
- le faire valider avant de publier.

`publier-windows.bat` refuse de publier si le marqueur ne correspond pas à la version.

## Publier une version

1. Monter `version:` dans `app/pubspec.yaml`, réécrire `RELEASE_NOTES.md`, commiter sur `main` et pousser.
2. Fabriquer l'APK : `scripts\build-android.ps1` (il doit être dans `dist\` : la release le joint pour le bouton
   « Obtenir l'application mobile » du Grenier).
3. `publier-windows.bat` : fabrique `dist\Grimoire-Setup-<version>.exe` (installateur sans assistant, `installer\`) et
   crée la release GitHub `v<version>` avec l'installateur, l'APK et le rapport.

Le Grenier compare le tag de la dernière release à la version installée : sans nouvelle release, aucune mise à jour
ne lui apparaît.
