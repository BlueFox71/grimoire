# Export Booknode → Grimoire

Grimoire ne contacte jamais Booknode. L'export est fait **par Claude, à la demande de Jules**, dans le Chrome de Jules connecté à son compte Booknode.

## Ce que fait l'export

1. Lit la vue détaillée de la bibliothèque (`/profil/<pseudo>/biblio-table`, 250 livres par page) pour chaque liste importée (PAL, En train de lire, Diamant, Or, Argent, Bronze, Pas apprécié, Lu aussi) et chaque type (livre, manga, BD, webtoon). Les **Envies** et la **Poubelle** ne sont jamais lues.
2. Pour chaque livre nouveau ou « à compléter » (moins de 3 étiquettes retenues dans l'export précédent) : lit sa fiche (couverture, résumé, série, tome) et sa page « Thèmes et Tropes ».
3. Produit un objet `grimoire-booknode-export` version 1 (format dans `docs/superpowers/specs/2026-11-07-grimoire-design.md`).

Règles : lectures de même origine dans l'onglet de Jules, aucun en-tête modifié, **une requête par seconde** (`pause: 1000`). Compter environ 30 à 40 minutes pour ~900 livres la première fois, quelques minutes ensuite.

## Procédure (pour Claude)

1. Ouvrir un onglet sur `https://booknode.com/profil/Subarashi/biblio-table` (Jules doit être connecté).
2. Injecter `parse.js` puis `export.js` avec l'outil JavaScript du navigateur, en retirant les mots-clés `export` et les lignes `import` (les fonctions deviennent globales).
3. Lancer `startExport({ previous })` (`previous` = dernier export, ou rien la première fois).
4. Relire `window.__grimoireExport` (`phase`, `done`, `total`, `errors`) toutes les deux minutes environ.
5. Quand `phase === 'terminé'` : vérifier `summarize(window.__grimoireExport.result)` (comptes par liste à comparer aux compteurs de la bibliothèque Booknode), puis enregistrer le résultat en fichier `booknode-export-AAAA-MM-JJ.json` (avec l'accord de Jules pour le téléchargement).
6. Dans Grimoire sur le PC : Réglages → « Importer un export Booknode ».

## Tests

```
npm install
npm test
```

Les pages de `fixtures/` reproduisent la structure des pages Booknode relevée le 2026-11-07 (elles ne sont pas des copies intégrales). Si Booknode change sa mise en page, adapter `parse.js` et ces fixtures.
