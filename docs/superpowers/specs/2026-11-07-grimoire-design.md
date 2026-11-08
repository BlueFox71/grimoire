# Grimoire — conception

Date : 2026-11-07 · Projet : `D:\Documents\Logiciels persos\grimoire\`

Légende : **[Jules]** = décidé par Jules · **[choix Claude]** = proposé par Claude, Jules peut le contester.

## Pourquoi

Jules a une pile à lire (PAL) d'environ 700 livres, papier et numériques, suivie sur Booknode (compte `Subarashi`). Devant autant de livres, il n'arrive pas à trouver un livre qui corresponde à l'**envie du moment** (« ce soir, de la romance fantasy avec des fae et de l'enemies to lovers »). Booknode ne permet pas de filtrer sa propre PAL comme ça. [Jules]

Grimoire est une appli perso : sa PAL avec des **filtres par thème et par trope**, pour choisir rapidement son prochain livre. Ce n'est pas une liseuse : elle ne contient que des fiches de livres, pas les livres eux-mêmes. [Jules]

## Objectifs

1. **Accueil = la pile avec filtres** (maquette B validée par Jules) [Jules] :
   - barre de recherche (titre, auteur) ;
   - puces de filtre : thèmes (genres) et tropes ; cocher plusieurs puces garde les livres qui ont **toutes** les puces cochées (ET) [choix Claude] ;
   - le nombre de livres correspondants s'affiche au-dessus de la liste ;
   - chaque ligne : couverture, titre, auteur, quelques tropes ou thèmes, étoiles si le livre est noté ;
   - par défaut, seuls les livres **à lire** sont affichés ; un filtre de statut permet de voir les **lus** (et le livre **en cours**) [choix Claude, validé par Jules] ;
   - beaucoup de thèmes existent (Fourth Wing en a 29 sur Booknode) : les puces sont triées par nombre de livres de la PAL concernés, les plus fréquentes d'abord ; une puce « + » ouvre la liste complète avec une recherche [choix Claude].
2. **Fiche d'un livre** [choix Claude, validé par Jules] : couverture, titre, auteur, série et tome, résumé, thèmes et tropes ; boutons **« Je le lis »** (statut en cours), **« Lu »**, **note de 1 à 5 étoiles** et **commentaire** libre ; Jules peut ajouter ou retirer des thèmes et tropes à la main ; bouton **« Retirer de Grimoire »** (avec confirmation dans l'appli) : un livre retiré ne revient ni à la synchro ni au réimport [choix Claude].
3. **Import depuis Booknode** [Jules pour le périmètre ; mode d'import choisi par Jules le 2026-11-07] :
   - **l'appli ne contacte jamais Booknode.** L'export est fait **par Claude, à la demande de Jules, dans le Chrome de Jules** (connecté à son compte), à un rythme humain (≈ 1 page/s), et produit un fichier `booknode-export.json` (format dans « Format d'export ») ; l'appli PC a un bouton **« Importer un export Booknode »** qui lit ce fichier et applique les règles ci-dessous. Le premier export et chaque réimport se font ainsi ;
   - listes importées : **Ma PAL** (682) → à lire ; **En train de lire** (1) → en cours ; listes de lus → lu avec note : **Diamant ★5, Or ★4, Argent ★3, Bronze ★2** [Jules] ; **Pas apprécié ★1**, **J'ai lu aussi** = lu sans note [choix Claude] ;
   - **jamais importées : Mes envies, Poubelle** [Jules] ;
   - types de publication : tous (livres, mangas, webtoons, BD) tant qu'ils sont dans les listes ci-dessus [choix Claude] ;
   - pour chaque livre : titre, auteur(s), couverture, résumé, série et numéro de tome, lien Booknode, et la page **« Thèmes et Tropes »** (`https://booknode.com/<slug>_<id>/themes`) ;
   - on garde un thème ou un trope si personne ne le conteste (0 vote contre), ou s'il a au moins 3 votes pour et deux fois plus de pour que de contre [choix Claude, assoupli le 2026-11-08 après avoir vu les vraies données : beaucoup de livres peu lus n'ont que 0 à 2 votes par thème]. Exemple : « Young Adult » sur Fourth Wing (27 pour / 16 contre) est écarté ;
   - un livre avec moins de 3 thèmes retenus est marqué « à compléter » ; Jules complète à la main depuis la fiche [choix Claude ; une complétion automatique à partir du résumé est hors périmètre de la v1] ;
   - l'import peut être **relancé** (nouvel export, puis « Importer un export Booknode »). Jules **continue d'utiliser Booknode ET Grimoire** [Jules], donc le réimport reprend les changements faits sur Booknode depuis le dernier import, selon ces règles [choix Claude] :
     - Grimoire mémorise, pour chaque livre, la **liste Booknode vue au dernier import** (PAL, Diamant, Or…) ;
     - si la liste a changé sur Booknode et que Jules n'a **pas** modifié le statut/la note dans Grimoire depuis le dernier import → Grimoire applique le changement (ex. PAL → Or = lu ★4) ;
     - si Jules a modifié le statut/la note dans Grimoire depuis le dernier import → **Grimoire garde sa valeur** (et le livre apparaît dans le résumé de l'import comme « différent de Booknode ») ;
     - nouveau livre dans la PAL ou dans une liste de lus → ajouté ;
     - livre sorti de toutes les listes importées (supprimé, passé en Envies ou Poubelle) → retiré de Grimoire, sauf s'il y est en cours ou lu avec une note/un commentaire saisi dans Grimoire ; listé dans le résumé ;
     - les commentaires et les thèmes/tropes retouchés à la main ne sont jamais modifiés par le réimport ;
     - Grimoire n'écrit **jamais** sur Booknode : ce qui est fait dans Grimoire reste dans Grimoire ;
     - **réexport rapide** (côté Claude) : la liste de la bibliothèque est relue en entier, mais les fiches et pages « Thèmes et Tropes » ne sont relues que pour les livres absents de l'export précédent et ceux « à compléter » ; un export partiel ne contient donc pas forcément les détails de tous les livres, et l'import ne vide jamais des détails existants faute de détails dans le fichier ;
     - un livre ajouté dans Grimoire via Google Books qui apparaît ensuite dans l'export Booknode est reconnu (même titre et même premier auteur, comparés sans accents ni casse) et complété au lieu d'être doublé ;
     - résumé à la fin : ajoutés / mis à jour / retirés / différents de Booknode.
4. **Ajouter un nouveau livre** (PC et téléphone) : Jules tape un titre ; Grimoire cherche sur **Google Books** (API publique `https://www.googleapis.com/books/v1/volumes?q=…`), Jules choisit un résultat, la fiche est créée (titre, auteurs, résumé, couverture), statut « à lire », sans tropes donc « à compléter ». Jules ajoute ses thèmes/tropes à la main, ou le livre est complété au prochain export s'il est aussi dans sa PAL Booknode. Ajout entièrement manuel possible (titre + auteur) si Google Books ne trouve rien ou s'il n'y a pas de réseau [Jules pour le principe, choix Claude pour la source]. Le scan du code-barres est hors périmètre de la v1 [choix Claude].
5. **Synchronisation PC ↔ téléphone par QR code**, comme Passe-Partout [Jules] :
   - sur le PC : bouton « Synchroniser le téléphone » → QR code ; le téléphone le scanne sur le Wi-Fi de la maison ;
   - pas de cloud, pas de compte en ligne ;
   - les modifications des deux côtés sont **fusionnées**, rien n'est écrasé en silence (voir « Données et fusion ») ;
   - résumé affiché des deux côtés : livres reçus / envoyés.
6. **Apparence** [Jules] : mode **sombre « Grimoire nocturne »** (violet nuit `#1b1626`, violet `#8a5cf6`, or `#e8c77a`) et mode **clair « Aube rosée »** (fond `#fbf4f6`, framboise `#a8456f`, texte `#3b2733`) ; titres en serif type Cormorant Garamond, texte en sans-serif type Nunito Sans. Par défaut, suit le réglage du système, avec un bouton pour forcer clair ou sombre [choix Claude]. Maquettes : https://claude.ai/artifact/NTVFne3gPk9L2DuWJEFVCB (version 1 = écrans d'accueil, version 2 = couleurs).

## Non-objectifs

- Lire des livres, stocker des fichiers EPUB/PDF. [Jules]
- Les Envies Booknode. [Jules]
- Écrire quoi que ce soit sur Booknode, ou que l'appli accède elle-même à Booknode. [choix Claude ; accès par l'appli écarté par Jules]
- iPhone, cloud, comptes, plusieurs utilisateurs. [choix Claude, cohérent avec Passe-Partout]
- Tirage au sort, tuiles de thèmes (maquettes A et C non retenues). [Jules]

## Anti-objectifs (ce qui ferait rater le projet même si « ça marche ») [proposés par Claude ; Jules n'en a pas cité]

- Une PAL importée incomplète ou avec des doublons (le total doit correspondre à Booknode).
- Des filtres noyés sous des thèmes inutiles ou faux.
- Une appli lente : cocher un filtre doit répondre immédiatement avec ~900 livres ; les couvertures sont stockées sur l'appareil.
- Perdre une note, un « lu » ou un commentaire à cause d'une synchro.
- Un rendu générique qui ne fait pas « grimoire ».

## Contraintes

- **Flutter**, applis **Android** et **Windows**, comme Disney Music (`D:\Documents\Logiciels persos\disney-music`, Flutter dans `C:\dev\flutter\bin`, scripts `build-android.ps1` / `build-windows.ps1` à reprendre). [Jules]
- **Booknode refuse les requêtes automatisées** (403 sur un téléchargement direct). On ne contourne **pas** cette protection : pas de faux en-têtes de navigateur, pas de client HTTP déguisé, **aucun accès à Booknode depuis l'appli**. Seul l'export fait par Claude dans le vrai Chrome de Jules, à sa demande, lit Booknode.
- Les couvertures sont des URL `cdn1.booknode.com/...` (ou Google Books). Les appareils les téléchargent comme de simples images ; si le CDN Booknode refuse, la couverture reste un aplat de couleur avec le titre (pas de contournement) [choix Claude].
- Données observées sur Booknode le 2026-11-07 (structure pouvant changer) :
  - bibliothèque : `https://booknode.com/profil/Subarashi/biblio-table` (vue détaillée : nom, auteur(s), liste, groupe, date d'ajout ; 25/100/250 par page ; filtre par liste : Diamant, Or, Argent, Bronze, Lu aussi, Envies, Poubelle, En train de lire, Pas apprécié, PAL) ;
  - fiche livre `https://booknode.com/<slug>_<id>` : bloc JSON-LD `schema.org/Book` (nom, image de couverture, auteur, description), série et tome dans la page ;
  - page `…/themes` : deux sections **Thèmes** et **Tropes**, chaque entrée avec son nom, ses votes pour et ses votes contre ;
  - la recherche : `https://booknode.com/search?q=<texte>`.
  Le script d'export (JavaScript exécuté par Claude dans l'onglet Booknode de Jules, lectures de même origine espacées d'≈ 1 s) vit dans `tools/booknode-export/` ; ses fonctions d'analyse sont testées sur des pages HTML enregistrées, pour être réparées facilement si Booknode change.
- Volume : ~900 livres (682 PAL + ~230 lus + 1 en cours), ~900 couvertures.

## Données et fusion [choix Claude]

- Stockage local par appareil (base SQLite ou fichier JSON, au choix du bâtisseur), couvertures en fichiers.
- Chaque livre : identifiant Booknode (ou identifiant local si ajouté depuis Google Books), titre, auteurs, série, tome, résumé, URL de couverture + fichier local, thèmes `[{nom, pour, contre}]`, tropes `[{nom, pour, contre}]`, thèmes/tropes ajoutés et retirés par Jules, statut (à lire / en cours / lu), note (0–5), commentaire, date de lecture, date d'ajout, et pour chaque champ modifiable par Jules une **date de dernière modification**.
- **Fusion à la synchro** : champ par champ, la modification la plus récente gagne ; les livres présents d'un seul côté sont ajoutés de l'autre ; une suppression laisse une trace (pierre tombale) pour ne pas réapparaître. Le PC fait une sauvegarde de sa base avant d'enregistrer le résultat d'une synchro.
- **Protocole** : le PC ouvre un petit serveur HTTP sur le réseau local pendant 2 minutes et affiche un QR code contenant ses adresses IP, le port et une clé aléatoire à usage unique ; le téléphone envoie ses données avec cette clé ; une requête sans la bonne clé est refusée. Le chiffrement complet façon Passe-Partout n'est pas nécessaire (une liste de livres n'est pas sensible), la clé suffit à empêcher un autre appareil du réseau de lire ou modifier la base.
- Couvertures : chaque appareil les télécharge lui-même depuis leur URL, en tâche de fond, et les garde en cache ; elles ne passent pas par la synchro.

## Format d'export [choix Claude]

`booknode-export.json`, UTF-8 :

```json
{
  "format": "grimoire-booknode-export",
  "version": 1,
  "exportedAt": "2026-11-07T21:00:00Z",
  "user": "Subarashi",
  "complete": true,
  "books": [
    {
      "booknodeId": "03477053",
      "url": "https://booknode.com/fourth_wing_03477053",
      "title": "Fourth Wing",
      "authors": ["Rebecca Yarros"],
      "type": "livre",
      "list": "pal",
      "addedAt": "2024-01-15",
      "details": {
        "coverUrl": "https://cdn1.booknode.com/book_cover/5806/full/fourth-wing-5805999.jpg",
        "summary": "Rien ne prédestinait Violet Sorrengail…",
        "series": "The Empyrean",
        "volume": 1,
        "themes": [{"name": "Dragons", "up": 171, "down": 1}],
        "tropes": [{"name": "Ennemis à amants (Enemies to lovers)", "up": 41, "down": 6}]
      }
    }
  ]
}
```

- `list` ∈ `pal`, `en_cours`, `diamant`, `or`, `argent`, `bronze`, `pas_apprecie`, `lu_aussi` (les livres d'autres listes ne sont pas exportés).
- `type` ∈ `livre`, `manga`, `webtoon`, `bd`.
- `details` vaut `null` quand le réexport rapide n'a pas relu la fiche ; `series`/`volume` valent `null` hors série.
- `complete: true` signifie que **toutes** les listes importées ont été relues : seul un export complet autorise l'import à retirer des livres absents.
- Les votes bruts sont conservés ; le filtrage (≥ 2× et ≥ 3) se fait dans l'appli.

## Laissé au bâtisseur

- Gestion d'état, base locale, bibliothèques Flutter (scan de QR, SQLite…), en préférant les plus maintenues et celles déjà utilisées dans Disney Music.
- Mise en page exacte de la fiche livre et de l'écran de synchro, dans l'esprit des maquettes.
- Icône de l'appli (sur le thème grimoire, dans les couleurs ci-dessus).
- Distribution (APK installé à la main, exe Windows), comme Disney Music.
