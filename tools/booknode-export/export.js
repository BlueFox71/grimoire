// Export de la bibliothèque Booknode de Jules vers booknode-export.json.
// Exécuté par Claude dans l'onglet Booknode de Jules (connecté), après parse.js.
// Lectures de même origine uniquement, sans modifier aucun en-tête, une requête
// toutes les `pause` ms. La progression est lisible dans window.__grimoireExport.

import { parseLibraryPage, parseBookPage, parseThemesPage } from './parse.js';

/** Valeur du filtre « list » de biblio-table → liste de l'export. Envies (6) et Poubelle (7) exclues. */
export const LISTS = { 10: 'pal', 8: 'en_cours', 1: 'diamant', 2: 'or', 3: 'argent', 4: 'bronze', 9: 'pas_apprecie', 5: 'lu_aussi' };
/** Valeur du filtre « media_type » → type de l'export. */
export const TYPES = { book: 'livre', manga: 'manga', graphic_novel: 'bd', webtoon: 'webtoon' };
export const PER_PAGE = 250;

// Même règle que l'appli (app/lib/core/tags.dart) : non contesté, ou au moins 3 pour et 2× plus de pour que de contre.
const kept = (t) => t.down === 0 || (t.up >= 3 && t.up >= 2 * t.down);

/** Faut-il relire la fiche et les thèmes de ce livre ? (absent de l'export précédent, ou « à compléter ») */
export function needsDetails(previousBook) {
  if (!previousBook || !previousBook.details) return true;
  const d = previousBook.details;
  return [...(d.themes || []), ...(d.tropes || [])].filter(kept).length < 3;
}

/**
 * Pause entre deux requêtes. Dans un onglet en arrière-plan, Chrome ralentit fortement
 * les setTimeout enchaînés (jusqu'à un réveil par minute) : on minute donc les pauses
 * dans un Web Worker, qui n'est pas soumis à ce ralentissement.
 */
function makeSleep() {
  if (typeof Worker === 'undefined' || typeof Blob === 'undefined' || typeof URL === 'undefined') {
    return (ms) => new Promise((r) => setTimeout(r, ms));
  }
  const src = 'onmessage = (e) => setTimeout(() => postMessage(e.data.id), e.data.ms);';
  const worker = new Worker(URL.createObjectURL(new Blob([src], { type: 'text/javascript' })));
  const waiting = new Map();
  let next = 0;
  worker.onmessage = (e) => {
    const resolve = waiting.get(e.data);
    waiting.delete(e.data);
    if (resolve) resolve();
  };
  return (ms) =>
    new Promise((resolve) => {
      const id = next++;
      waiting.set(id, resolve);
      worker.postMessage({ id, ms });
    });
}

export async function runExport({ previous = null, pause = 1000, fetchDoc = null, user = null } = {}) {
  const state = (globalThis.__grimoireExport = { phase: 'listes', done: 0, total: 0, errors: [], result: null, running: true });
  const who = user || (globalThis.location && (location.pathname.match(/^\/profil\/([^/]+)/) || [])[1]);
  if (!who) throw new Error('Ouvre d\'abord la page de ta bibliothèque Booknode.');
  const sleep = makeSleep();
  const getDoc =
    fetchDoc ||
    (async (url) => {
      const res = await fetch(url, { credentials: 'include' });
      if (!res.ok) throw new Error(`HTTP ${res.status} pour ${url}`);
      return new DOMParser().parseFromString(await res.text(), 'text/html');
    });
  let first = true;
  const politeDoc = async (url) => {
    if (!first) await sleep(pause);
    first = false;
    return getDoc(url);
  };

  const prevById = new Map(((previous && previous.books) || []).map((b) => [b.booknodeId, b]));
  const books = new Map();
  state.books = books; // lisible pendant l'export (reprise possible avec `previous`)
  let listsOk = true;
  state.total = Object.keys(LISTS).length * Object.keys(TYPES).length;

  // 1. Listes (chaque liste × chaque type de publication).
  for (const [listValue, list] of Object.entries(LISTS)) {
    for (const [mediaType, type] of Object.entries(TYPES)) {
      const base = `https://booknode.com/profil/${who}/biblio-table?per_page=${PER_PAGE}&media_type=${mediaType}&list=${listValue}&sort=book_name`;
      try {
        // On suit les livres réellement reçus : on continue tant qu'il en manque et que la page n'est pas vide.
        let page = 1;
        let collected = 0;
        let announced = 0;
        let skipped = 0;
        for (;;) {
          const res = parseLibraryPage(await politeDoc(`${base}&page=${page}`));
          announced = Math.max(announced, res.total);
          skipped += res.skipped || 0;
          collected += res.rows.length;
          for (const r of res.rows) {
            if (!books.has(r.booknodeId)) books.set(r.booknodeId, { ...r, type, list, details: null });
          }
          if (res.rows.length === 0 || collected + skipped >= announced) break;
          page++;
        }
        if (collected < announced) {
          listsOk = false;
          state.errors.push(`${list}/${type} : ${collected} livres lus sur ${announced} annoncés`);
        }
      } catch (e) {
        listsOk = false;
        state.errors.push(`${list}/${type} : ${e.message}`);
      }
      state.done++;
    }
  }

  // 2. Fiches et thèmes des livres nouveaux ou « à compléter ».
  const todo = [...books.values()].filter((b) => needsDetails(prevById.get(b.booknodeId)));
  state.phase = 'fiches';
  state.done = 0;
  state.total = todo.length;
  for (const b of todo) {
    try {
      const page = parseBookPage(await politeDoc(b.url));
      const { themes, tropes } = parseThemesPage(await politeDoc(`${b.url}/themes`));
      b.details = {
        coverUrl: page.coverUrl || b.thumbUrl,
        summary: page.summary,
        series: page.series,
        volume: page.volume,
        themes,
        tropes,
      };
    } catch (e) {
      state.errors.push(`${b.title} : ${e.message}`);
    }
    state.done++;
  }

  const result = {
    format: 'grimoire-booknode-export',
    version: 1,
    exportedAt: new Date().toISOString(),
    user: who,
    complete: listsOk,
    books: [...books.values()].map(({ thumbUrl, ...b }) => b),
  };
  state.result = result;
  state.phase = 'terminé';
  state.running = false;
  return result;
}

/** Lance l'export sans l'attendre (Claude relit window.__grimoireExport). */
export function startExport(options) {
  runExport(options).catch((e) => {
    globalThis.__grimoireExport = { ...(globalThis.__grimoireExport || {}), running: false, fatal: e.message };
  });
  return 'export lancé';
}

/** Résumé lisible de l'export (comptes par liste, livres sans détails). */
export function summarize(result) {
  const byList = {};
  for (const b of result.books) byList[b.list] = (byList[b.list] || 0) + 1;
  return {
    total: result.books.length,
    byList,
    withThemes: result.books.filter((b) => b.details && b.details.themes.length).length,
    noDetails: result.books.filter((b) => !b.details).length,
    complete: result.complete,
  };
}
